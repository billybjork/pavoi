import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Track environment at runtime (for conditional behavior in workers, etc.)
config :social_objects, env: :test
config :social_objects, use_brand_domains_in_outbound: false

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :social_objects, SocialObjects.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "social_objects_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :social_objects, SocialObjectsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "NIrpSRXH3mfni/zdZgtPr69eFFricLiEcl4hWojtV9gi3ly/wK/X3eX3SwtkeDrR",
  server: false

# In test we don't send emails
config :social_objects, SocialObjects.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Avoid storing creator avatars in test
config :social_objects, :creator_avatars, store_in_storage: false, store_locally: false

# Disable Oban background processing in test to avoid sandbox ownership conflicts
config :social_objects, Oban,
  testing: :manual,
  queues: false,
  plugins: false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Avoid external live checks during tests
config :social_objects, :verify_stream_live_status, false

# Disable OpenAI retries in tests to avoid delays
config :social_objects, SocialObjects.AI.OpenAIClient,
  max_retries: 1,
  initial_backoff_ms: 0
