defmodule Pavoi.Repo.Migrations.AddLarkPresetToEmailTemplates do
  use Ecto.Migration

  def change do
    alter table(:email_templates) do
      # Which Lark community to redirect to after SMS consent
      # Options: jewelry, active, top_creators
      add :lark_preset, :string, default: "jewelry"
    end
  end
end
