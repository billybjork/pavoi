defmodule Pavoi.Settings do
  @moduledoc """
  The Settings context for managing system-wide configuration.
  """

  import Ecto.Query, warn: false
  alias Pavoi.Repo
  alias Pavoi.Settings.SystemSetting

  @doc """
  Gets the last Shopify sync timestamp.

  Returns nil if never synced or a DateTime if synced before.
  """
  def get_shopify_last_sync_at do
    case Repo.get_by(SystemSetting, key: "shopify_last_sync_at") do
      nil -> nil
      setting -> parse_datetime(setting.value)
    end
  end

  @doc """
  Updates the last Shopify sync timestamp to the current time.
  """
  def update_shopify_last_sync_at do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case Repo.get_by(SystemSetting, key: "shopify_last_sync_at") do
      nil ->
        %SystemSetting{}
        |> SystemSetting.changeset(%{
          key: "shopify_last_sync_at",
          value: now,
          value_type: "datetime"
        })
        |> Repo.insert()

      setting ->
        setting
        |> SystemSetting.changeset(%{value: now})
        |> Repo.update()
    end
  end

  @doc """
  Gets the last TikTok Shop sync timestamp.

  Returns nil if never synced or a DateTime if synced before.
  """
  def get_tiktok_last_sync_at do
    case Repo.get_by(SystemSetting, key: "tiktok_last_sync_at") do
      nil -> nil
      setting -> parse_datetime(setting.value)
    end
  end

  @doc """
  Updates the last TikTok Shop sync timestamp to the current time.
  """
  def update_tiktok_last_sync_at do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case Repo.get_by(SystemSetting, key: "tiktok_last_sync_at") do
      nil ->
        %SystemSetting{}
        |> SystemSetting.changeset(%{
          key: "tiktok_last_sync_at",
          value: now,
          value_type: "datetime"
        })
        |> Repo.insert()

      setting ->
        setting
        |> SystemSetting.changeset(%{value: now})
        |> Repo.update()
    end
  end

  @doc """
  Gets the last TikTok Live scan timestamp.

  Returns nil if never scanned or a DateTime if scanned before.
  """
  def get_tiktok_live_last_scan_at do
    case Repo.get_by(SystemSetting, key: "tiktok_live_last_scan_at") do
      nil -> nil
      setting -> parse_datetime(setting.value)
    end
  end

  @doc """
  Updates the last TikTok Live scan timestamp to the current time.
  """
  def update_tiktok_live_last_scan_at do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case Repo.get_by(SystemSetting, key: "tiktok_live_last_scan_at") do
      nil ->
        %SystemSetting{}
        |> SystemSetting.changeset(%{
          key: "tiktok_live_last_scan_at",
          value: now,
          value_type: "datetime"
        })
        |> Repo.insert()

      setting ->
        setting
        |> SystemSetting.changeset(%{value: now})
        |> Repo.update()
    end
  end

  @doc """
  Gets the last BigQuery orders sync timestamp.

  Returns nil if never synced or a DateTime if synced before.
  """
  def get_bigquery_last_sync_at do
    case Repo.get_by(SystemSetting, key: "bigquery_last_sync_at") do
      nil -> nil
      setting -> parse_datetime(setting.value)
    end
  end

  @doc """
  Updates the last BigQuery orders sync timestamp to the current time.
  """
  def update_bigquery_last_sync_at do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case Repo.get_by(SystemSetting, key: "bigquery_last_sync_at") do
      nil ->
        %SystemSetting{}
        |> SystemSetting.changeset(%{
          key: "bigquery_last_sync_at",
          value: now,
          value_type: "datetime"
        })
        |> Repo.insert()

      setting ->
        setting
        |> SystemSetting.changeset(%{value: now})
        |> Repo.update()
    end
  end

  @doc """
  Gets the last creator enrichment sync timestamp.

  Returns nil if never synced or a DateTime if synced before.
  """
  def get_enrichment_last_sync_at do
    case Repo.get_by(SystemSetting, key: "enrichment_last_sync_at") do
      nil -> nil
      setting -> parse_datetime(setting.value)
    end
  end

  @doc """
  Updates the last creator enrichment sync timestamp to the current time.
  """
  def update_enrichment_last_sync_at do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case Repo.get_by(SystemSetting, key: "enrichment_last_sync_at") do
      nil ->
        %SystemSetting{}
        |> SystemSetting.changeset(%{
          key: "enrichment_last_sync_at",
          value: now,
          value_type: "datetime"
        })
        |> Repo.insert()

      setting ->
        setting
        |> SystemSetting.changeset(%{value: now})
        |> Repo.update()
    end
  end

  @doc """
  Gets the last creator videos import timestamp.

  Returns nil if never imported or a DateTime if imported before.
  """
  def get_videos_last_import_at do
    case Repo.get_by(SystemSetting, key: "videos_last_import_at") do
      nil -> nil
      setting -> parse_datetime(setting.value)
    end
  end

  @doc """
  Updates the last creator videos import timestamp to the current time.
  """
  def update_videos_last_import_at do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    case Repo.get_by(SystemSetting, key: "videos_last_import_at") do
      nil ->
        %SystemSetting{}
        |> SystemSetting.changeset(%{
          key: "videos_last_import_at",
          value: now,
          value_type: "datetime"
        })
        |> Repo.insert()

      setting ->
        setting
        |> SystemSetting.changeset(%{value: now})
        |> Repo.update()
    end
  end

  @doc """
  Gets a generic string setting by key.

  Returns nil if the setting doesn't exist.
  """
  def get_setting(key) when is_binary(key) do
    case Repo.get_by(SystemSetting, key: key) do
      nil -> nil
      setting -> setting.value
    end
  end

  @doc """
  Sets a generic string setting.

  Creates the setting if it doesn't exist, updates it if it does.
  """
  def set_setting(key, value) when is_binary(key) and is_binary(value) do
    case Repo.get_by(SystemSetting, key: key) do
      nil ->
        %SystemSetting{}
        |> SystemSetting.changeset(%{
          key: key,
          value: value,
          value_type: "string"
        })
        |> Repo.insert()

      setting ->
        setting
        |> SystemSetting.changeset(%{value: value})
        |> Repo.update()
    end
  end

  # =============================================================================
  # Enrichment Rate Limit Tracking
  # =============================================================================

  @doc """
  Gets the last time enrichment was rate limited.
  Returns nil if never rate limited.
  """
  def get_enrichment_last_rate_limited_at do
    case Repo.get_by(SystemSetting, key: "enrichment_last_rate_limited_at") do
      nil -> nil
      setting -> parse_datetime(setting.value)
    end
  end

  @doc """
  Gets the current rate limit streak (consecutive rate limits).
  Returns 0 if no streak.
  """
  def get_enrichment_rate_limit_streak do
    case Repo.get_by(SystemSetting, key: "enrichment_rate_limit_streak") do
      nil -> 0
      setting -> String.to_integer(setting.value)
    end
  end

  @doc """
  Records a rate limit event. Increments the streak counter.
  """
  def record_enrichment_rate_limit do
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    streak = get_enrichment_rate_limit_streak() + 1

    upsert_setting("enrichment_last_rate_limited_at", now, "datetime")
    upsert_setting("enrichment_rate_limit_streak", Integer.to_string(streak), "integer")

    streak
  end

  @doc """
  Resets the rate limit streak after a successful enrichment run.
  """
  def reset_enrichment_rate_limit_streak do
    upsert_setting("enrichment_rate_limit_streak", "0", "integer")
  end

  defp upsert_setting(key, value, value_type) do
    case Repo.get_by(SystemSetting, key: key) do
      nil ->
        %SystemSetting{}
        |> SystemSetting.changeset(%{key: key, value: value, value_type: value_type})
        |> Repo.insert()

      setting ->
        setting
        |> SystemSetting.changeset(%{value: value})
        |> Repo.update()
    end
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> datetime
      {:error, _} -> nil
    end
  end
end
