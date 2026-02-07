defmodule Pavoi.Accounts.BrandInvite do
  @moduledoc """
  Represents an invite for a user to join a brand.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(owner admin viewer)a

  schema "brand_invites" do
    field :email, :string
    field :role, Ecto.Enum, values: @roles, default: :viewer
    field :expires_at, :utc_datetime
    field :accepted_at, :utc_datetime

    belongs_to :brand, Pavoi.Catalog.Brand
    belongs_to :invited_by_user, Pavoi.Accounts.User, foreign_key: :invited_by_user_id

    timestamps(type: :utc_datetime)
  end

  def changeset(invite, attrs) do
    invite
    |> cast(attrs, [:email, :role, :expires_at, :accepted_at, :brand_id, :invited_by_user_id])
    |> validate_required([:email, :role, :brand_id])
    |> validate_format(:email, ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/)
    |> unique_constraint(:email, name: :brand_invites_brand_id_email_index)
  end
end
