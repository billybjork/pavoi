defmodule Pavoi.Repo.Migrations.CreateSessionStreams do
  use Ecto.Migration

  def change do
    create table(:session_streams) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :stream_id, references(:tiktok_streams, on_delete: :delete_all), null: false
      add :linked_at, :utc_datetime, null: false
      add :linked_by, :string, size: 20

      timestamps()
    end

    create unique_index(:session_streams, [:session_id, :stream_id])
    create index(:session_streams, [:session_id])
    create index(:session_streams, [:stream_id])
  end
end
