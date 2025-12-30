defmodule Pavoi.Communications.EmailTemplate do
  @moduledoc """
  Schema for email templates stored in the database.

  Templates are stored as complete HTML and can be edited via
  a source editor in the admin interface.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @lark_presets ~w(jewelry active top_creators)

  schema "email_templates" do
    field :name, :string
    field :subject, :string
    field :html_body, :string
    field :text_body, :string
    field :is_active, :boolean, default: true
    field :is_default, :boolean, default: false
    field :lark_preset, :string, default: "jewelry"

    timestamps()
  end

  def lark_presets, do: @lark_presets

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [
      :name,
      :subject,
      :html_body,
      :text_body,
      :is_active,
      :is_default,
      :lark_preset
    ])
    |> validate_required([:name, :subject, :html_body])
    |> validate_inclusion(:lark_preset, @lark_presets)
    |> unique_constraint(:name)
  end
end
