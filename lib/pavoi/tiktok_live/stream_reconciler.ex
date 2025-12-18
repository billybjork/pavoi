defmodule Pavoi.TiktokLive.StreamReconciler do
  @moduledoc """
  Reconciles stream state on application startup.

  Finds streams that are marked as "capturing" but have no active Oban worker,
  which can happen after application restarts or crashes. For each orphaned stream:
  - If the stream is still live, restart capture
  - If the stream is no longer live, mark as ended
  """

  require Logger

  alias Pavoi.Repo
  alias Pavoi.TiktokLive.{Client, Stream}
  alias Pavoi.Workers.TiktokLiveStreamWorker

  import Ecto.Query

  @doc """
  Runs stream reconciliation. Should be called on application startup.

  Returns the number of streams that were reconciled.
  """
  def run do
    # First, cancel any stale scheduled/executing jobs for TikTok streams
    # These would have been left over from a previous deploy
    cancelled = cancel_stale_stream_jobs()

    if cancelled > 0 do
      Logger.info("Stream reconciliation: cancelled #{cancelled} stale Oban jobs")
    end

    # Now find orphaned streams (those with no active jobs)
    orphaned_streams = find_orphaned_capturing_streams()

    if Enum.empty?(orphaned_streams) do
      Logger.debug("Stream reconciliation: no orphaned streams found")
      cancelled
    else
      Logger.info("Stream reconciliation: found #{length(orphaned_streams)} orphaned streams")

      Enum.each(orphaned_streams, fn stream ->
        reconcile_orphaned_stream(stream)
      end)

      cancelled + length(orphaned_streams)
    end
  end

  # Check if stream is still live and restart capture, otherwise mark as ended
  defp reconcile_orphaned_stream(stream) do
    case Client.fetch_room_info(stream.unique_id) do
      {:ok, %{is_live: true, room_id: room_id}} when room_id == stream.room_id ->
        # Stream is still live with same room_id, restart capture
        Logger.info("Stream #{stream.id} (@#{stream.unique_id}) is still live, restarting capture")
        restart_capture(stream)

      {:ok, %{is_live: true}} ->
        # Live but different room_id means this is a new stream
        Logger.info("Stream #{stream.id} (@#{stream.unique_id}) has new room_id, marking as ended")
        mark_stream_ended(stream)

      _ ->
        # Not live or error checking, mark as ended
        Logger.info("Stream #{stream.id} (@#{stream.unique_id}) is no longer live, marking as ended")
        mark_stream_ended(stream)
    end
  end

  defp restart_capture(stream) do
    %{stream_id: stream.id, unique_id: stream.unique_id}
    |> TiktokLiveStreamWorker.new()
    |> Oban.insert()
  end

  @doc """
  Cancels stale Oban jobs for stream capture that were left over from a deploy.
  Jobs in 'scheduled' or 'executing' state are considered stale on startup.
  """
  def cancel_stale_stream_jobs do
    query = """
    UPDATE oban_jobs
    SET state = 'cancelled', cancelled_at = NOW()
    WHERE worker = 'Pavoi.Workers.TiktokLiveStreamWorker'
      AND state IN ('scheduled', 'executing')
    RETURNING id
    """

    case Repo.query(query) do
      {:ok, %{num_rows: count}} -> count
      {:error, _} -> 0
    end
  end

  @doc """
  Finds streams marked as "capturing" that don't have an active Oban job.
  """
  def find_orphaned_capturing_streams do
    # Get all capturing streams
    capturing_streams =
      Stream
      |> where([s], s.status == :capturing)
      |> Repo.all()

    # Get active Oban job stream IDs
    active_job_stream_ids = get_active_job_stream_ids()

    # Filter to streams without active jobs
    Enum.reject(capturing_streams, fn stream ->
      stream.id in active_job_stream_ids
    end)
  end

  defp get_active_job_stream_ids do
    # Query Oban jobs for our worker that are in active states
    query = """
    SELECT args->>'stream_id' as stream_id
    FROM oban_jobs
    WHERE worker = 'Pavoi.Workers.TiktokLiveStreamWorker'
      AND state IN ('available', 'scheduled', 'executing', 'retryable')
    """

    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        rows
        |> Enum.map(fn [id] -> String.to_integer(id) end)
        |> MapSet.new()

      {:error, _} ->
        MapSet.new()
    end
  end

  defp mark_stream_ended(stream) do
    Logger.info(
      "Marking orphaned stream #{stream.id} (@#{stream.unique_id}) as ended"
    )

    stream
    |> Stream.changeset(%{
      status: :ended,
      ended_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Repo.update()
  end
end
