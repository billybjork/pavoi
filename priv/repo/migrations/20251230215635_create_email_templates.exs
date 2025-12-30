defmodule Pavoi.Repo.Migrations.CreateEmailTemplates do
  use Ecto.Migration

  def change do
    create table(:email_templates) do
      add :name, :string, null: false
      add :display_name, :string, null: false
      add :subject, :string, null: false
      add :html_body, :text, null: false
      add :text_body, :text
      add :is_active, :boolean, default: true, null: false
      add :is_default, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:email_templates, [:name])
    create index(:email_templates, [:is_active])
  end
end
