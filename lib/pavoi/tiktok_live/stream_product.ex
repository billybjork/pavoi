defmodule Pavoi.TiktokLive.StreamProduct do
  @moduledoc """
  Represents a product showcased during a TikTok live stream.

  Products are captured from TikTok's shopping events during live broadcasts.
  Multiple showcases of the same product increment the showcase_count.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "tiktok_stream_products" do
    field :tiktok_product_id, :string
    field :title, :string
    field :price_cents, :integer
    field :image_url, :string
    field :first_seen_at, :utc_datetime
    field :showcase_count, :integer, default: 1

    belongs_to :stream, Pavoi.TiktokLive.Stream

    timestamps()
  end

  @doc false
  def changeset(stream_product, attrs) do
    stream_product
    |> cast(attrs, [
      :stream_id,
      :tiktok_product_id,
      :title,
      :price_cents,
      :image_url,
      :first_seen_at,
      :showcase_count
    ])
    |> validate_required([:stream_id, :tiktok_product_id])
    |> unique_constraint([:stream_id, :tiktok_product_id])
    |> foreign_key_constraint(:stream_id)
  end
end
