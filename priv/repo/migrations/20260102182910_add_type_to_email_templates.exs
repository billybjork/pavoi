defmodule Pavoi.Repo.Migrations.AddTypeToEmailTemplates do
  use Ecto.Migration

  def change do
    alter table(:email_templates) do
      # "email" or "page" - default to "email" for existing records
      add :type, :string, null: false, default: "email"

      # Page templates store form customization as JSON
      # e.g., {"button_text": "JOIN NOW", "phone_label": "Phone", ...}
      add :form_config, :map, default: %{}
    end

    # Index for type-filtered queries
    create index(:email_templates, [:type, :is_active])
  end
end
