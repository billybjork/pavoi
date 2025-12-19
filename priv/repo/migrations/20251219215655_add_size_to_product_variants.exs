defmodule Pavoi.Repo.Migrations.AddSizeToProductVariants do
  use Ecto.Migration

  def change do
    alter table(:product_variants) do
      # Normalized size value (e.g., "7", "6.5", "18\"", "3mm", "Small")
      add :size, :string
      # Size type for categorization (ring, length, diameter, apparel)
      add :size_type, :string
      # Source of size extraction for debugging (shopify_options, tiktok_attributes, sku, name)
      add :size_source, :string
    end

    create index(:product_variants, [:size])
    create index(:product_variants, [:size_type])
  end
end
