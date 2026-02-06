defmodule Pavoi.Accounts.UserBrand do
  @moduledoc """
  Represents a user's access to a brand with a specific role.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(owner admin viewer)

  schema "user_brands" do
    belongs_to :user, Pavoi.Accounts.User
    belongs_to :brand, Pavoi.Catalog.Brand
    field :role, :string, default: "viewer"

    timestamps()
  end

  @doc """
  Returns the list of valid roles.
  """
  def roles, do: @roles

  @doc false
  def changeset(user_brand, attrs) do
    user_brand
    |> cast(attrs, [:role])
    |> validate_required([:role])
    |> validate_inclusion(:role, @roles)
  end
end
