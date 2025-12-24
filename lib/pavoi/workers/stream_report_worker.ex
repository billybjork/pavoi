defmodule Pavoi.Workers.StreamReportWorker do
  @moduledoc """
  Oban worker that generates and sends Slack reports when TikTok Live streams end.

  The report includes:
  - Stream cover image (if captured)
  - Stream statistics (duration, viewers, likes, gifts, comments)
  - Top 5 products referenced in comments
  - Flash sale activity summary
  - AI-powered sentiment analysis of comments

  ## Job Arguments
  - `stream_id` - ID of the completed stream
  """

  use Oban.Worker,
    queue: :slack,
    max_attempts: 3,
    unique: [period: 300, keys: [:stream_id]]

  require Logger

  alias Pavoi.StreamReport

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"stream_id" => stream_id}}) do
    Logger.info("Generating stream report for stream #{stream_id}")

    with {:ok, report_data} <- StreamReport.generate(stream_id),
         {:ok, :sent} <- StreamReport.send_to_slack(report_data) do
      Logger.info("Stream report sent successfully for stream #{stream_id}")
      :ok
    else
      {:error, "Slack not configured" <> _} = error ->
        # Slack not configured - log warning but don't retry
        Logger.warning("Skipping stream report - Slack not configured")
        {:cancel, error}

      {:error, reason} ->
        Logger.error("Failed to send stream report for stream #{stream_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
