defmodule Pavoi.Creators.BrandCreator do
  @moduledoc """
  Junction table linking creators to brands they work with.

  Enables multi-brand support where a creator can work with multiple brands,
  and each brand-creator relationship can have its own status and notes.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(active inactive blocked)a

  schema "brand_creators" do
    belongs_to :brand, Pavoi.Catalog.Brand
    belongs_to :creator, Pavoi.Creators.Creator

    field :status, Ecto.Enum, values: @statuses, default: :active
    field :joined_at, :utc_datetime
    field :notes, :string

    timestamps()
  end

  @doc false
  def changeset(brand_creator, attrs) do
    brand_creator
    |> cast(attrs, [:brand_id, :creator_id, :status, :joined_at, :notes])
    |> validate_required([:brand_id, :creator_id])
    |> unique_constraint([:brand_id, :creator_id])
    |> foreign_key_constraint(:brand_id)
    |> foreign_key_constraint(:creator_id)
  end

  @doc """
  Returns the list of valid statuses.
  """
  def statuses, do: @statuses
end
