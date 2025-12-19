defmodule Pavoi.Repo.Migrations.AddSizeRangeToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      # Human-readable size range (e.g., "5-9", "16\"-20\"", "3mm-30mm")
      add :size_range, :string
      # Boolean flag: true if product has multiple size variants
      add :has_size_variants, :boolean, default: false
    end
  end
end
