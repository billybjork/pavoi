defmodule Pavoi.TiktokLive.Comment do
  @moduledoc """
  Represents a comment captured from a TikTok live stream.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "tiktok_comments" do
    field :tiktok_user_id, :string
    field :tiktok_username, :string
    field :tiktok_nickname, :string
    field :comment_text, :string
    field :commented_at, :utc_datetime
    field :raw_event, :map, default: %{}

    belongs_to :stream, Pavoi.TiktokLive.Stream

    timestamps()
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [
      :stream_id,
      :tiktok_user_id,
      :tiktok_username,
      :tiktok_nickname,
      :comment_text,
      :commented_at,
      :raw_event
    ])
    |> validate_required([:stream_id, :tiktok_user_id, :comment_text, :commented_at])
    |> foreign_key_constraint(:stream_id)
  end
end
