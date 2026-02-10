defmodule Pavoi.Repo.Migrations.AddVideoSearchIndexes do
  use Ecto.Migration

  # Required for CREATE INDEX CONCURRENTLY
  @disable_ddl_transaction true
  @disable_migration_lock true

  def up do
    # Enable pg_trgm extension for trigram-based indexes (fast ILIKE)
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    # GIN trigram index on video title for fast ILIKE searches
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS creator_videos_title_trgm_idx
    ON creator_videos USING gin (title gin_trgm_ops)
    """

    # GIN trigram index on creator username for fast ILIKE searches
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS creators_tiktok_username_trgm_idx
    ON creators USING gin (tiktok_username gin_trgm_ops)
    """

    # Composite index for brand_id + gmv sorting (common query pattern)
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS creator_videos_brand_gmv_idx
    ON creator_videos (brand_id, gmv_cents DESC NULLS LAST)
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS creator_videos_title_trgm_idx"
    execute "DROP INDEX IF EXISTS creators_tiktok_username_trgm_idx"
    execute "DROP INDEX IF EXISTS creator_videos_brand_gmv_idx"
  end
end
