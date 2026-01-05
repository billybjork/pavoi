defmodule Mix.Tasks.ImportSessions do
  @moduledoc """
  Import sessions from a CSV file exported from Google Sheets.

  The CSV should have columns: session_name, session_description, product_skus
  where product_skus are pipe-delimited (e.g., "SKU1|SKU2|SKU3")

  Products are matched by SKU with partial matching support (first match wins).

  ## Usage

      # Development environment
      mix import_sessions path/to/sessions.csv

      # Production environment
      MIX_ENV=prod mix import_sessions path/to/sessions.csv

  ## Options

      --dry-run    Show what would be imported without making changes
      --brand      Specify brand name (default: "PAVOI")
  """

  use Mix.Task
  require Logger

  NimbleCSV.define(SessionsCSV, separator: ",", escape: "\"")

  @shortdoc "Import sessions from CSV file"

  @impl Mix.Task
  def run(args) do
    # Start the application
    Mix.Task.run("app.start")

    {opts, args, _} =
      OptionParser.parse(args,
        switches: [dry_run: :boolean, brand: :string],
        aliases: [d: :dry_run, b: :brand]
      )

    csv_path = List.first(args)

    unless csv_path do
      Mix.shell().error("Error: CSV file path required")
      Mix.shell().info("Usage: mix import_sessions <csv_file>")
      exit({:shutdown, 1})
    end

    unless File.exists?(csv_path) do
      Mix.shell().error("Error: File not found: #{csv_path}")
      exit({:shutdown, 1})
    end

    dry_run = Keyword.get(opts, :dry_run, false)
    brand_name = Keyword.get(opts, :brand, "PAVOI")

    if dry_run do
      Mix.shell().info("DRY RUN MODE - No changes will be made\n")
    end

    Mix.shell().info("Importing sessions from: #{csv_path}")
    Mix.shell().info("Brand: #{brand_name}\n")

    # Find the brand
    brand = find_or_create_brand(brand_name, dry_run)

    unless brand do
      Mix.shell().error("Error: Could not find or create brand: #{brand_name}")
      exit({:shutdown, 1})
    end

    Mix.shell().info("Using brand: #{brand.name} (ID: #{brand.id})\n")

    # Parse and import CSV
    stats = import_csv(csv_path, brand.id, dry_run)

    # Print summary
    print_summary(stats)
  end

  defp find_or_create_brand(brand_name, dry_run) do
    case Pavoi.Catalog.get_brand_by_name(brand_name) do
      nil -> create_brand(brand_name, dry_run)
      brand -> brand
    end
  end

  defp create_brand(brand_name, true = _dry_run) do
    Mix.shell().info("Would create brand: #{brand_name}")
    %{id: 999, name: brand_name}
  end

  defp create_brand(brand_name, false = _dry_run) do
    case Pavoi.Catalog.create_brand(%{name: brand_name, slug: slugify_brand(brand_name)}) do
      {:ok, brand} ->
        Mix.shell().info("Created brand: #{brand_name}")
        brand

      {:error, changeset} ->
        Mix.shell().error("Failed to create brand: #{inspect(changeset.errors)}")
        nil
    end
  end

  defp slugify_brand(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
  end

  defp import_csv(csv_path, brand_id, dry_run) do
    stats = %{
      sessions_processed: 0,
      sessions_created: 0,
      products_added: 0,
      missing_pids: [],
      errors: []
    }

    csv_path
    |> File.read!()
    |> SessionsCSV.parse_string(skip_headers: false)
    |> parse_csv_rows()
    |> Enum.reduce(stats, fn row, acc ->
      process_row(row, brand_id, dry_run, acc)
    end)
  end

  defp parse_csv_rows([headers | rows]) do
    # Convert rows to maps using headers
    header_atoms =
      headers
      |> Enum.map(&String.trim/1)
      |> Enum.map(&String.downcase/1)
      |> Enum.map(&String.replace(&1, " ", "_"))

    Enum.map(rows, fn row ->
      header_atoms
      |> Enum.zip(row)
      |> Map.new()
    end)
  end

  defp process_row(row, brand_id, dry_run, stats) do
    session_name = Map.get(row, "session_name", "")

    # Skip empty rows
    if session_name == "" do
      stats
    else
      do_process_row(row, session_name, brand_id, dry_run, stats)
    end
  end

  defp do_process_row(row, session_name, brand_id, dry_run, stats) do
    session_description = Map.get(row, "session_description", "")
    product_skus_str = Map.get(row, "product_skus", "")

    stats = Map.update!(stats, :sessions_processed, &(&1 + 1))
    Mix.shell().info("Processing: #{session_name}")

    # Parse and find products
    product_skus = parse_product_skus(product_skus_str)
    Mix.shell().info("  SKUs to import: #{length(product_skus)}")

    {products, missing} = find_products_by_skus(product_skus)

    # Track missing SKUs
    stats = track_missing_skus(stats, missing, session_name)
    Mix.shell().info("  Found products: #{length(products)}")

    # Create session with products
    create_or_skip_session(session_name, session_description, brand_id, products, dry_run, stats)
  end

  defp parse_product_skus(product_skus_str) do
    product_skus_str
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp track_missing_skus(stats, [], _session_name), do: stats

  defp track_missing_skus(stats, missing, session_name) do
    Mix.shell().info("  ⚠️  Missing SKUs: #{Enum.join(missing, ", ")}")

    Map.update!(stats, :missing_pids, fn skus ->
      skus ++ Enum.map(missing, fn sku -> %{session: session_name, pid: sku} end)
    end)
  end

  defp create_or_skip_session(session_name, _description, _brand_id, [], _dry_run, stats) do
    Mix.shell().error("  ✗ Skipping (no products found)\n")

    Map.update!(stats, :errors, fn errors ->
      errors ++ [%{session: session_name, error: "No products found"}]
    end)
  end

  defp create_or_skip_session(session_name, description, brand_id, products, dry_run, stats) do
    do_create_session(session_name, description, brand_id, products, dry_run, stats)
  end

  defp do_create_session(_session_name, _description, _brand_id, products, true = _dry_run, stats) do
    Mix.shell().info("  ✓ Would create session with #{length(products)} products\n")

    stats
    |> Map.update!(:sessions_created, &(&1 + 1))
    |> Map.update!(:products_added, &(&1 + length(products)))
  end

  defp do_create_session(session_name, description, brand_id, products, false = _dry_run, stats) do
    case create_session_with_products(session_name, description, brand_id, products) do
      {:ok, session} ->
        Mix.shell().info("  ✓ Created session: #{session.name} (#{length(products)} products)\n")

        stats
        |> Map.update!(:sessions_created, &(&1 + 1))
        |> Map.update!(:products_added, &(&1 + length(products)))

      {:error, reason} ->
        error_msg = "Failed to create session '#{session_name}': #{inspect(reason)}"
        Mix.shell().error("  ✗ #{error_msg}\n")

        Map.update!(stats, :errors, fn errors ->
          errors ++ [%{session: session_name, error: error_msg}]
        end)
    end
  end

  defp find_products_by_skus(skus) do
    # Find products by SKU with partial matching (first match wins)
    results =
      Enum.map(skus, fn sku ->
        case Pavoi.Catalog.find_product_by_sku(sku) do
          nil -> {:missing, sku}
          product -> {:found, product}
        end
      end)

    # Separate found products from missing SKUs
    products =
      results
      |> Enum.filter(fn {status, _} -> status == :found end)
      |> Enum.map(fn {:found, product} -> product end)

    missing_skus =
      results
      |> Enum.filter(fn {status, _} -> status == :missing end)
      |> Enum.map(fn {:missing, sku} -> sku end)

    {products, missing_skus}
  end

  defp create_session_with_products(name, description, brand_id, products) do
    # Generate slug from name
    slug = Pavoi.ProductSets.slugify(name)

    session_attrs = %{
      name: name,
      slug: slug,
      brand_id: brand_id,
      notes: description,
      status: "active"
    }

    product_ids = Enum.map(products, & &1.id)

    Pavoi.ProductSets.create_product_set_with_products(session_attrs, product_ids)
  end

  defp print_summary(stats) do
    Mix.shell().info("""

    ═══════════════════════════════════════════════════════════
    Import Summary
    ═══════════════════════════════════════════════════════════
    Sessions processed:  #{stats.sessions_processed}
    Sessions created:    #{stats.sessions_created}
    Products added:      #{stats.products_added}
    Missing SKUs:        #{length(stats.missing_pids)}
    Errors:              #{length(stats.errors)}
    ═══════════════════════════════════════════════════════════
    """)

    if length(stats.missing_pids) > 0 do
      Mix.shell().info("Missing SKUs Details:")
      Mix.shell().info("─────────────────────────────────────────────────────────")

      stats.missing_pids
      |> Enum.group_by(& &1.session)
      |> Enum.each(fn {session, skus} ->
        sku_list = Enum.map_join(skus, ", ", & &1.pid)
        Mix.shell().info("  #{session}:")
        Mix.shell().info("    #{sku_list}")
      end)

      Mix.shell().info("")
    end

    if length(stats.errors) > 0 do
      Mix.shell().error("Errors:")
      Mix.shell().error("─────────────────────────────────────────────────────────")

      Enum.each(stats.errors, fn error ->
        Mix.shell().error("  #{error.session}: #{error.error}")
      end)

      Mix.shell().info("")
    end

    if stats.sessions_created > 0 do
      Mix.shell().info("✓ Import completed successfully!")
    else
      Mix.shell().error("✗ No sessions were created")
    end
  end
end
