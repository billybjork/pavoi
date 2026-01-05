defmodule Pavoi.TiktokLive.ProductSetStream do
  @moduledoc """
  Join table linking TikTok live streams to product sets.

  A stream can be linked to multiple product sets (e.g., if products from
  multiple product sets were discussed), and a product set can be linked to
  multiple streams (e.g., if a product set was used for multiple broadcasts).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "product_set_streams" do
    field :linked_at, :utc_datetime
    field :linked_by, :string

    belongs_to :product_set, Pavoi.ProductSets.ProductSet
    belongs_to :stream, Pavoi.TiktokLive.Stream

    timestamps()
  end

  @doc false
  def changeset(product_set_stream, attrs) do
    product_set_stream
    |> cast(attrs, [:product_set_id, :stream_id, :linked_at, :linked_by])
    |> validate_required([:product_set_id, :stream_id, :linked_at])
    |> validate_inclusion(:linked_by, ["auto", "manual"])
    |> unique_constraint([:product_set_id, :stream_id])
    |> foreign_key_constraint(:product_set_id)
    |> foreign_key_constraint(:stream_id)
  end
end
