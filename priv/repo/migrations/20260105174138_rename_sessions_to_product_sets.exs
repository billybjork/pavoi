defmodule Pavoi.Repo.Migrations.RenameSessionsToProductSets do
  use Ecto.Migration

  def up do
    # Step 1: Rename the main tables
    rename table(:sessions), to: table(:product_sets)
    rename table(:session_products), to: table(:product_set_products)
    rename table(:session_states), to: table(:product_set_states)
    rename table(:session_streams), to: table(:product_set_streams)

    # Step 2: Rename columns in product_set_products (was session_products)
    rename table(:product_set_products), :session_id, to: :product_set_id

    # Step 3: Rename columns in product_set_states (was session_states)
    rename table(:product_set_states), :session_id, to: :product_set_id

    rename table(:product_set_states), :current_session_product_id,
      to: :current_product_set_product_id

    # Step 4: Rename columns in product_set_streams (was session_streams)
    rename table(:product_set_streams), :session_id, to: :product_set_id

    # Step 5: Rename columns in related tables
    rename table(:tiktok_streams), :session_id, to: :product_set_id
    rename table(:tiktok_comments), :session_product_id, to: :product_set_product_id
    rename table(:talking_points_generations), :session_id, to: :product_set_id

    # Step 6: Update indexes (drop old, create new)
    # product_set_products indexes
    execute "DROP INDEX IF EXISTS session_products_session_id_position_index"
    execute "DROP INDEX IF EXISTS session_products_session_id_product_id_index"
    execute "DROP INDEX IF EXISTS session_products_session_id_index"

    create unique_index(:product_set_products, [:product_set_id, :position])
    create unique_index(:product_set_products, [:product_set_id, :product_id])
    create index(:product_set_products, [:product_set_id])

    # product_set_states indexes
    execute "DROP INDEX IF EXISTS session_states_session_id_index"
    create unique_index(:product_set_states, [:product_set_id])

    # product_set_streams indexes
    execute "DROP INDEX IF EXISTS session_streams_session_id_stream_id_index"
    execute "DROP INDEX IF EXISTS session_streams_session_id_index"
    execute "DROP INDEX IF EXISTS session_streams_stream_id_index"

    create unique_index(:product_set_streams, [:product_set_id, :stream_id])
    create index(:product_set_streams, [:product_set_id])
    create index(:product_set_streams, [:stream_id])

    # tiktok_streams index
    execute "DROP INDEX IF EXISTS tiktok_streams_session_id_index"
    create index(:tiktok_streams, [:product_set_id])

    # tiktok_comments index
    execute "DROP INDEX IF EXISTS tiktok_comments_session_product_id_index"
    create index(:tiktok_comments, [:product_set_product_id])

    # talking_points_generations index
    execute "DROP INDEX IF EXISTS talking_points_generations_session_id_index"
    create index(:talking_points_generations, [:product_set_id])
  end

  def down do
    # Step 1: Restore indexes first (drop new, recreate old)
    # talking_points_generations
    execute "DROP INDEX IF EXISTS talking_points_generations_product_set_id_index"
    create index(:talking_points_generations, [:session_id])

    # tiktok_comments
    execute "DROP INDEX IF EXISTS tiktok_comments_product_set_product_id_index"
    create index(:tiktok_comments, [:session_product_id])

    # tiktok_streams
    execute "DROP INDEX IF EXISTS tiktok_streams_product_set_id_index"
    create index(:tiktok_streams, [:session_id])

    # product_set_streams
    execute "DROP INDEX IF EXISTS product_set_streams_product_set_id_stream_id_index"
    execute "DROP INDEX IF EXISTS product_set_streams_product_set_id_index"
    execute "DROP INDEX IF EXISTS product_set_streams_stream_id_index"

    create unique_index(:session_streams, [:session_id, :stream_id])
    create index(:session_streams, [:session_id])
    create index(:session_streams, [:stream_id])

    # product_set_states
    execute "DROP INDEX IF EXISTS product_set_states_product_set_id_index"
    create unique_index(:session_states, [:session_id])

    # product_set_products
    execute "DROP INDEX IF EXISTS product_set_products_product_set_id_position_index"
    execute "DROP INDEX IF EXISTS product_set_products_product_set_id_product_id_index"
    execute "DROP INDEX IF EXISTS product_set_products_product_set_id_index"

    create unique_index(:session_products, [:session_id, :position])
    create unique_index(:session_products, [:session_id, :product_id])
    create index(:session_products, [:session_id])

    # Step 2: Rename columns back in related tables
    rename table(:talking_points_generations), :product_set_id, to: :session_id
    rename table(:tiktok_comments), :product_set_product_id, to: :session_product_id
    rename table(:tiktok_streams), :product_set_id, to: :session_id

    # Step 3: Rename columns back in product_set_streams
    rename table(:product_set_streams), :product_set_id, to: :session_id

    # Step 4: Rename columns back in product_set_states
    rename table(:product_set_states), :current_product_set_product_id,
      to: :current_session_product_id

    rename table(:product_set_states), :product_set_id, to: :session_id

    # Step 5: Rename columns back in product_set_products
    rename table(:product_set_products), :product_set_id, to: :session_id

    # Step 6: Rename tables back
    rename table(:product_set_streams), to: table(:session_streams)
    rename table(:product_set_states), to: table(:session_states)
    rename table(:product_set_products), to: table(:session_products)
    rename table(:product_sets), to: table(:sessions)
  end
end
