defmodule Pavoi.Repo.Migrations.AddTiktokProductIdsArrayToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :tiktok_product_ids, {:array, :string}, default: []
    end

    # Create a GIN index for efficient array searching
    create index(:products, [:tiktok_product_ids], using: :gin)

    # Migrate existing tiktok_product_id values to the array
    execute(
      "UPDATE products SET tiktok_product_ids = ARRAY[tiktok_product_id] WHERE tiktok_product_id IS NOT NULL",
      "SELECT 1"
    )
  end
end
