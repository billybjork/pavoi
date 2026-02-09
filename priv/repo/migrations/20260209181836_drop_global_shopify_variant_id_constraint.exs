defmodule Pavoi.Repo.Migrations.DropGlobalShopifyVariantIdConstraint do
  use Ecto.Migration

  @moduledoc """
  Drops the global unique constraint on product_variants.shopify_variant_id.

  This allows multiple brands to share a Shopify store where the same variant
  IDs may exist in different brands (filtered by tags). The uniqueness is now
  enforced at the product level (products have brand-scoped unique PIDs), and
  variants are tied to products via product_id.
  """

  def change do
    # Drop the global unique index on shopify_variant_id
    drop_if_exists unique_index(:product_variants, [:shopify_variant_id])
  end
end
