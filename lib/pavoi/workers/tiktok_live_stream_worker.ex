defmodule Pavoi.Workers.TiktokLiveStreamWorker do
  @moduledoc """
  Oban worker that manages the capture process for a single TikTok live stream.

  This worker:
  1. Starts the WebSocket Connection to Euler Stream's hosted service
  2. Starts the Event Handler for persisting events
  3. Monitors both processes and restarts them if they crash
  4. Runs until the stream ends or connection fails

  The worker is designed to be long-running (up to several hours for a live stream).
  It uses Oban's snooze mechanism to periodically check if the stream is still active.
  """

  use Oban.Worker,
    queue: :tiktok,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:stream_id], states: [:available, :scheduled, :executing]]

  require Logger

  alias Pavoi.Repo
  alias Pavoi.TiktokLive.{Connection, EventHandler, Stream}

  # Check stream status every 5 minutes
  @status_check_interval_seconds 300

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"stream_id" => stream_id, "unique_id" => unique_id}}) do
    Logger.info("Starting capture worker for stream #{stream_id}, @#{unique_id}")

    # Check if stream still exists and is in capturing state
    case Repo.get(Stream, stream_id) do
      nil ->
        Logger.warning("Stream #{stream_id} not found, aborting capture")
        :ok

      %Stream{status: :ended} ->
        Logger.info("Stream #{stream_id} has ended, aborting capture")
        :ok

      %Stream{status: :failed} ->
        Logger.info("Stream #{stream_id} has failed, aborting capture")
        :ok

      stream ->
        run_capture(stream, unique_id)
    end
  end

  defp run_capture(stream, unique_id) do
    stream_id = stream.id

    # Start the event handler first so it's ready to receive events
    event_handler_opts = [
      stream_id: stream_id,
      name: event_handler_name(stream_id)
    ]

    case EventHandler.start_link(event_handler_opts) do
      {:ok, event_handler_pid} ->
        start_connection(stream_id, unique_id, event_handler_pid)

      {:error, {:already_started, pid}} ->
        Logger.info("Event handler already running for stream #{stream_id}")
        start_connection(stream_id, unique_id, pid)

      {:error, reason} ->
        Logger.error("Failed to start event handler: #{inspect(reason)}")
        mark_stream_failed(stream)
        {:error, reason}
    end
  end

  defp start_connection(stream_id, unique_id, event_handler_pid) do
    connection_opts = [
      unique_id: unique_id,
      stream_id: stream_id,
      name: connection_name(stream_id)
    ]

    case Connection.start_link(connection_opts) do
      {:ok, connection_pid} ->
        monitor_capture(stream_id, connection_pid, event_handler_pid)

      {:error, {:already_started, pid}} ->
        Logger.info("Connection already running for stream #{stream_id}")
        monitor_capture(stream_id, pid, event_handler_pid)

      {:error, :missing_api_key} ->
        Logger.error("Euler Stream API key not configured")
        stop_event_handler(event_handler_pid)
        {:error, :missing_api_key}

      {:error, reason} ->
        Logger.error("Failed to start connection: #{inspect(reason)}")
        stop_event_handler(event_handler_pid)
        # Snooze and retry
        {:snooze, 60}
    end
  end

  defp monitor_capture(stream_id, connection_pid, event_handler_pid) do
    # Monitor both processes
    connection_ref = Process.monitor(connection_pid)
    event_handler_ref = Process.monitor(event_handler_pid)

    # Subscribe to stream events to detect stream end
    Phoenix.PubSub.subscribe(Pavoi.PubSub, "tiktok_live:stream:#{stream_id}")

    result =
      capture_loop(
        stream_id,
        connection_pid,
        event_handler_pid,
        connection_ref,
        event_handler_ref
      )

    # Cleanup
    Process.demonitor(connection_ref, [:flush])
    Process.demonitor(event_handler_ref, [:flush])
    Phoenix.PubSub.unsubscribe(Pavoi.PubSub, "tiktok_live:stream:#{stream_id}")

    result
  end

  defp capture_loop(
         stream_id,
         connection_pid,
         event_handler_pid,
         connection_ref,
         event_handler_ref
       ) do
    receive do
      # Stream ended naturally
      {:tiktok_live_stream_event, {:stream_ended}} ->
        Logger.info("Stream #{stream_id} ended")
        cleanup_processes(connection_pid, event_handler_pid)
        :ok

      # Connection failed permanently
      {:tiktok_live_stream_event, {:connection_failed}} ->
        Logger.error("Connection failed for stream #{stream_id}")
        cleanup_processes(connection_pid, event_handler_pid)
        :ok

      # Connection process died
      {:DOWN, ^connection_ref, :process, ^connection_pid, reason} ->
        Logger.warning("Connection process died: #{inspect(reason)}")
        stop_event_handler(event_handler_pid)
        # Check if stream is still capturing
        case Repo.get(Stream, stream_id) do
          %Stream{status: :capturing} ->
            # Snooze and retry
            {:snooze, 30}

          _ ->
            :ok
        end

      # Event handler process died
      {:DOWN, ^event_handler_ref, :process, ^event_handler_pid, reason} ->
        Logger.warning("Event handler process died: #{inspect(reason)}")
        stop_connection(connection_pid)
        # Snooze and retry
        {:snooze, 30}

      # Periodic status check (use timeout)
      _other ->
        capture_loop(
          stream_id,
          connection_pid,
          event_handler_pid,
          connection_ref,
          event_handler_ref
        )
    after
      @status_check_interval_seconds * 1000 ->
        # Check if stream is still valid
        case Repo.get(Stream, stream_id) do
          %Stream{status: :capturing} ->
            # Continue monitoring
            capture_loop(
              stream_id,
              connection_pid,
              event_handler_pid,
              connection_ref,
              event_handler_ref
            )

          _ ->
            Logger.info("Stream #{stream_id} no longer in capturing state")
            cleanup_processes(connection_pid, event_handler_pid)
            :ok
        end
    end
  end

  defp cleanup_processes(connection_pid, event_handler_pid) do
    stop_connection(connection_pid)
    stop_event_handler(event_handler_pid)
  end

  defp stop_connection(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      Connection.stop(pid)
    end
  rescue
    _ -> :ok
  end

  defp stop_connection(_), do: :ok

  defp stop_event_handler(pid) when is_pid(pid) do
    if Process.alive?(pid) do
      EventHandler.stop(pid)
    end
  rescue
    _ -> :ok
  end

  defp stop_event_handler(_), do: :ok

  defp mark_stream_failed(stream) do
    stream
    |> Stream.changeset(%{status: :failed})
    |> Repo.update()
  end

  defp connection_name(stream_id) do
    {:via, Registry, {Pavoi.TiktokLive.Registry, {:connection, stream_id}}}
  end

  defp event_handler_name(stream_id) do
    {:via, Registry, {Pavoi.TiktokLive.Registry, {:event_handler, stream_id}}}
  end
end
