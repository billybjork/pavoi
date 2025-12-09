defmodule Pavoi.Repo.Migrations.AddOutreachFieldsToCreators do
  use Ecto.Migration

  def change do
    alter table(:creators) do
      # Outreach tracking
      # Values: "pending", "approved", "sent", "skipped"
      add :outreach_status, :string
      add :outreach_sent_at, :utc_datetime

      # SMS consent (required for TCPA compliance)
      add :sms_consent, :boolean, default: false
      add :sms_consent_at, :utc_datetime
    end

    create index(:creators, [:outreach_status])
  end
end
