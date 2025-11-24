defmodule Pavoi.Repo.Migrations.AddUniqueConstraintToTiktokProductId do
  use Ecto.Migration

  def change do
    # Drop the existing non-unique index
    drop_if_exists index(:products, [:tiktok_product_id])

    # Create a unique index (only for non-null values, like pid)
    create unique_index(:products, [:tiktok_product_id],
             where: "tiktok_product_id IS NOT NULL",
             name: :products_tiktok_product_id_unique_index
           )
  end
end
