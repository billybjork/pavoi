defmodule Pavoi.Repo.Migrations.AddNotesImageUrlToSessions do
  use Ecto.Migration

  def change do
    alter table(:sessions) do
      add :notes_image_url, :string
    end
  end
end
