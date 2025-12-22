defmodule Pavoi.TiktokLive.SessionStream do
  @moduledoc """
  Join table linking TikTok live streams to internal sessions.

  A stream can be linked to multiple sessions (e.g., if products from
  multiple sessions were discussed), and a session can be linked to
  multiple streams (e.g., if a session was used for multiple broadcasts).
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "session_streams" do
    field :linked_at, :utc_datetime
    field :linked_by, :string

    belongs_to :session, Pavoi.Sessions.Session
    belongs_to :stream, Pavoi.TiktokLive.Stream

    timestamps()
  end

  @doc false
  def changeset(session_stream, attrs) do
    session_stream
    |> cast(attrs, [:session_id, :stream_id, :linked_at, :linked_by])
    |> validate_required([:session_id, :stream_id, :linked_at])
    |> validate_inclusion(:linked_by, ["auto", "manual"])
    |> unique_constraint([:session_id, :stream_id])
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:stream_id)
  end
end
