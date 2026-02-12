defmodule SocialObjects.Repo.Migrations.AddManuallyEditedFieldsToCreators do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      add :manually_edited_fields, {:array, :string}, default: []
    end

    create index(:creators, [:manually_edited_fields], using: :gin)
  end
end
