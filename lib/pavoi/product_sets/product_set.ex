defmodule Pavoi.ProductSets.ProductSet do
  @moduledoc """
  Represents a product set for a brand.

  A product set is a collection of products to showcase during live streaming sessions,
  with an associated host, product lineup, and real-time state management.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_sets" do
    field :name, :string
    field :slug, :string
    field :notes, :string
    field :notes_image_url, :string

    belongs_to :brand, Pavoi.Catalog.Brand

    has_many :product_set_products, Pavoi.ProductSets.ProductSetProduct,
      preload_order: [asc: :position]

    has_one :product_set_state, Pavoi.ProductSets.ProductSetState
    # Direct relationship (stream.product_set_id -> product_set.id)
    has_many :tiktok_streams, Pavoi.TiktokLive.Stream, foreign_key: :product_set_id
    # Legacy join table relationship (for backward compatibility)
    has_many :product_set_streams, Pavoi.TiktokLive.ProductSetStream, foreign_key: :product_set_id
    has_many :streams, through: [:product_set_streams, :stream]

    timestamps()
  end

  @doc false
  def changeset(product_set, attrs) do
    product_set
    |> cast(attrs, [:brand_id, :name, :slug, :notes, :notes_image_url])
    |> validate_required([:brand_id, :name, :slug])
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:brand_id)
  end
end
