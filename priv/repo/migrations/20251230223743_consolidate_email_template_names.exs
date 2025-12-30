defmodule Pavoi.Repo.Migrations.ConsolidateEmailTemplateNames do
  use Ecto.Migration

  def up do
    # Copy display_name to name (display_name has the human-readable names)
    execute "UPDATE email_templates SET name = display_name"

    # Drop the display_name column
    alter table(:email_templates) do
      remove :display_name
    end
  end

  def down do
    # Re-add display_name column
    alter table(:email_templates) do
      add :display_name, :string
    end

    # Copy name back to display_name
    execute "UPDATE email_templates SET display_name = name"

    # Convert name back to snake_case format
    execute """
    UPDATE email_templates
    SET name = LOWER(REPLACE(name, ' ', '_'))
    """
  end
end
