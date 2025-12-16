defmodule Pavoi.Repo.Migrations.CreateTiktokLiveTables do
  use Ecto.Migration

  def change do
    # Create enum for stream status
    execute(
      "CREATE TYPE tiktok_stream_status AS ENUM ('capturing', 'ended', 'failed')",
      "DROP TYPE tiktok_stream_status"
    )

    # Main table for tracking live streams
    create table(:tiktok_streams) do
      add :room_id, :string, null: false
      add :unique_id, :string, null: false
      add :title, :string
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :status, :tiktok_stream_status, null: false, default: "capturing"
      add :viewer_count_peak, :integer, default: 0
      add :total_likes, :integer, default: 0
      add :total_comments, :integer, default: 0
      add :total_gifts_value, :integer, default: 0
      add :raw_metadata, :map, default: %{}

      timestamps()
    end

    create index(:tiktok_streams, [:unique_id])
    create index(:tiktok_streams, [:room_id])
    create index(:tiktok_streams, [:status])
    create index(:tiktok_streams, [:started_at])

    # Comments captured from live streams
    create table(:tiktok_comments) do
      add :stream_id, references(:tiktok_streams, on_delete: :delete_all), null: false
      add :tiktok_user_id, :string, null: false
      add :tiktok_username, :string
      add :tiktok_nickname, :string
      add :comment_text, :text, null: false
      add :commented_at, :utc_datetime, null: false
      add :raw_event, :map, default: %{}

      timestamps()
    end

    create index(:tiktok_comments, [:stream_id])
    create index(:tiktok_comments, [:stream_id, :commented_at])
    create index(:tiktok_comments, [:tiktok_user_id])

    # Time-series stats sampled during streams
    create table(:tiktok_stream_stats) do
      add :stream_id, references(:tiktok_streams, on_delete: :delete_all), null: false
      add :recorded_at, :utc_datetime, null: false
      add :viewer_count, :integer, default: 0
      add :like_count, :integer, default: 0
      add :gift_count, :integer, default: 0
      add :comment_count, :integer, default: 0

      timestamps()
    end

    create index(:tiktok_stream_stats, [:stream_id])
    create index(:tiktok_stream_stats, [:stream_id, :recorded_at])
  end
end
