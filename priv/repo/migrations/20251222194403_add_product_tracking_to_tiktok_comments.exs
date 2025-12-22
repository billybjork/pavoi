defmodule Pavoi.Repo.Migrations.AddProductTrackingToTiktokComments do
  use Ecto.Migration

  def change do
    alter table(:tiktok_comments) do
      add :session_product_id, references(:session_products, on_delete: :nilify_all)
      add :parsed_product_number, :integer
    end

    create index(:tiktok_comments, [:session_product_id])
    create index(:tiktok_comments, [:stream_id, :session_product_id])
  end
end
