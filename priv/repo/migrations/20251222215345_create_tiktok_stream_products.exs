defmodule Pavoi.Repo.Migrations.CreateTiktokStreamProducts do
  use Ecto.Migration

  def change do
    create table(:tiktok_stream_products) do
      add :stream_id, references(:tiktok_streams, on_delete: :delete_all), null: false
      add :tiktok_product_id, :string, null: false
      add :title, :string
      add :price_cents, :integer
      add :image_url, :string
      add :first_seen_at, :utc_datetime
      add :showcase_count, :integer, default: 1

      timestamps()
    end

    create unique_index(:tiktok_stream_products, [:stream_id, :tiktok_product_id])
    create index(:tiktok_stream_products, [:tiktok_product_id])
  end
end
