defmodule Pavoi.Workers.CreatorEnrichmentWorker do
  @moduledoc """
  Oban worker that enriches creator profiles with data from TikTok Marketplace API.

  ## Enrichment Strategy

  1. Find creators with usernames but missing/stale metrics
  2. Search marketplace API by username to find exact match
  3. Update creator with metrics from API response
  4. Create performance snapshot for historical tracking

  ## Prioritization (Recently Sampled First)

  1. Creators with samples in last 30 days (highest priority)
  2. Creators with no performance data ever
  3. Creators with stale data (>7 days since last enrichment)

  ## Rate Limits

  - Marketplace Search API: reasonable limits
  - Process in batches to avoid overwhelming the API
  """

  use Oban.Worker,
    queue: :enrichment,
    max_attempts: 3,
    unique: [period: :infinity, states: [:available, :scheduled, :executing]]

  require Logger
  import Ecto.Query

  alias Pavoi.Creators
  alias Pavoi.Creators.Creator
  alias Pavoi.Repo
  alias Pavoi.Settings
  alias Pavoi.TiktokShop

  # Number of creators to enrich per run
  # With 10k API requests/day limit and 4 runs/day, 2000/run = 8000/day
  @batch_size 2000
  # Delay between API calls (ms) to avoid rate limiting
  # 300ms is safe and keeps batch runtime ~10 minutes
  @api_delay_ms 300

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Phoenix.PubSub.broadcast(Pavoi.PubSub, "creator:enrichment", {:enrichment_started})

    # Step 1: Sync sample orders to link creators to their tiktok_user_id
    # This runs first so newly-linked creators can be enriched in step 2
    # Default to 20 pages (~2000 orders) to avoid rate limits when combined with enrichment
    sample_sync_pages = Map.get(args, "sample_sync_pages", 20)
    {:ok, sample_stats} = sync_sample_orders(max_pages: sample_sync_pages)

    # Brief pause between sample sync and enrichment to avoid rate limits
    # Both use TikTok APIs that may share rate limit buckets
    Process.sleep(5_000)

    # Step 2: Enrich creators with marketplace data (followers, GMV, etc.)
    batch_size = Map.get(args, "batch_size", @batch_size)
    Logger.info("Starting creator enrichment (batch_size: #{batch_size})...")

    {:ok, enrich_stats} = enrich_creators(batch_size)

    Settings.update_enrichment_last_sync_at()

    Logger.info("""
    Creator enrichment completed
       Sample sync:
         - Matched: #{sample_stats.matched}
         - Created: #{sample_stats.created}
         - Already linked: #{sample_stats.already_linked}
       Marketplace enrichment:
         - Enriched: #{enrich_stats.enriched}
         - Not found: #{enrich_stats.not_found}
         - Errors: #{enrich_stats.errors}
         - Skipped (no username): #{enrich_stats.skipped}
    """)

    combined_stats = Map.merge(sample_stats, enrich_stats)
    Phoenix.PubSub.broadcast(Pavoi.PubSub, "creator:enrichment", {:enrichment_completed, combined_stats})
    :ok
  end

  @doc """
  Manually trigger enrichment for a specific creator by username.
  Returns {:ok, creator} or {:error, reason}.
  """
  def enrich_single(creator) when is_struct(creator, Creator) do
    if creator.tiktok_username && creator.tiktok_username != "" do
      enrich_creator(creator)
    else
      {:error, :no_username}
    end
  end

  # =============================================================================
  # Sample Order Sync - Link creators to their TikTok user_id via sample orders
  # =============================================================================

  @doc """
  Syncs sample orders from TikTok API to identify and link creators.

  For sample orders (is_sample_order=true), the `user_id` field contains the
  creator's TikTok user ID (not a customer). This function:

  1. Fetches all orders from TikTok Orders API
  2. Filters for `is_sample_order == true`
  3. Matches to existing creators by phone/name
  4. Sets `tiktok_user_id` on matched creators
  5. Creates new creators for unmatched samples

  Call manually:
      Pavoi.Workers.CreatorEnrichmentWorker.sync_sample_orders()
  """
  def sync_sample_orders(opts \\ []) do
    max_pages = Keyword.get(opts, :max_pages, 100)
    Logger.info("[SampleSync] Starting sample orders sync (max_pages: #{max_pages})...")

    initial_stats = %{
      matched: 0,
      created: 0,
      already_linked: 0,
      skipped: 0,
      errors: 0,
      pages: 0
    }

    {:ok, stats} = sync_sample_orders_page(nil, initial_stats, max_pages)

    Logger.info("""
    [SampleSync] Completed
       - Matched existing creators: #{stats.matched}
       - Created new creators: #{stats.created}
       - Already linked: #{stats.already_linked}
       - Skipped (no match data): #{stats.skipped}
       - Errors: #{stats.errors}
       - Pages processed: #{stats.pages}
    """)

    {:ok, stats}
  end

  defp sync_sample_orders_page(_page_token, stats, max_pages) when stats.pages >= max_pages do
    Logger.info("[SampleSync] Reached max pages limit (#{max_pages})")
    {:ok, stats}
  end

  defp sync_sample_orders_page(page_token, stats, max_pages) do
    params = build_page_params(page_token)

    case TiktokShop.make_api_request(:post, "/order/202309/orders/search", params, %{}) do
      {:ok, %{"data" => data}} ->
        Process.sleep(@api_delay_ms)
        handle_orders_response(data, stats, max_pages)

      {:error, reason} ->
        Logger.error("[SampleSync] API error: #{inspect(reason)}")
        {:ok, stats}
    end
  end

  defp build_page_params(nil), do: %{page_size: 100}
  defp build_page_params(token), do: %{page_size: 100, page_token: token}

  defp handle_orders_response(data, stats, max_pages) do
    orders = Map.get(data, "orders", [])
    sample_orders = Enum.filter(orders, fn o -> o["is_sample_order"] == true end)

    new_stats = process_sample_orders(sample_orders, stats)
    new_stats = %{new_stats | pages: new_stats.pages + 1}

    maybe_continue_pagination(data["next_page_token"], new_stats, max_pages)
  end

  defp maybe_continue_pagination(token, stats, max_pages)
       when is_binary(token) and token != "" and stats.pages < max_pages do
    sync_sample_orders_page(token, stats, max_pages)
  end

  defp maybe_continue_pagination(_token, stats, _max_pages), do: {:ok, stats}

  defp process_sample_orders(orders, stats) do
    Enum.reduce(orders, stats, fn order, acc ->
      process_single_sample_order(order, acc)
    end)
  end

  defp process_single_sample_order(order, acc) do
    user_id = order["user_id"]
    recipient = order["recipient_address"] || %{}

    # Extract contact info (may be masked or unmasked)
    phone = extract_phone(recipient["phone_number"])
    name = recipient["name"] || ""
    {first_name, last_name} = Creators.parse_name(name)

    if is_nil(user_id) or user_id == "" do
      %{acc | skipped: acc.skipped + 1}
    else
      case find_creator_for_sample(phone, first_name, last_name) do
        {:found, creator} ->
          link_creator_to_user_id(creator, user_id, recipient, acc)

        :not_found ->
          create_creator_from_sample(user_id, recipient, acc)
      end
    end
  rescue
    e ->
      Logger.error("[SampleSync] Error processing order: #{Exception.message(e)}")
      %{acc | errors: acc.errors + 1}
  end

  defp find_creator_for_sample(phone, first_name, last_name) do
    # Try exact phone match first (for unmasked phones)
    creator =
      if phone && !phone_is_masked?(phone) do
        Creators.get_creator_by_phone(phone)
      else
        nil
      end

    # Try partial phone match (for masked phones like "(+1)808*****50")
    creator =
      creator || try_partial_phone_match(phone)

    # Fall back to name match
    creator =
      creator ||
        if first_name && String.length(first_name) > 1 && !String.contains?(first_name, "*") do
          Creators.get_creator_by_name(first_name, last_name)
        else
          nil
        end

    if creator, do: {:found, creator}, else: :not_found
  end

  defp try_partial_phone_match(nil), do: nil
  defp try_partial_phone_match(""), do: nil

  defp try_partial_phone_match(phone) do
    # Extract area code and last digits from masked phone like "(+1)808*****50"
    case Regex.run(~r/\+1\)?(\d{3})\*+(\d+)$/, phone) do
      [_, area_code, last_digits] when byte_size(last_digits) >= 2 ->
        pattern = "%#{area_code}%#{last_digits}"

        # Find creators matching the pattern - prefer exact matches
        matches =
          from(c in Creator,
            where: like(c.phone, ^pattern),
            limit: 5
          )
          |> Repo.all()

        # Return first match if only one, nil if ambiguous
        case matches do
          [single] -> single
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp link_creator_to_user_id(creator, user_id, recipient, acc) do
    if creator.tiktok_user_id do
      # Already has a user_id - check if it matches
      if creator.tiktok_user_id == user_id do
        %{acc | already_linked: acc.already_linked + 1}
      else
        # Different user_id - log warning but don't overwrite
        Logger.warning(
          "[SampleSync] Creator #{creator.id} has different tiktok_user_id: #{creator.tiktok_user_id} vs #{user_id}"
        )

        %{acc | already_linked: acc.already_linked + 1}
      end
    else
      # Set the user_id and update any missing contact info
      attrs = build_update_attrs(creator, user_id, recipient)

      case Creators.update_creator(creator, attrs) do
        {:ok, _updated} ->
          Logger.debug(
            "[SampleSync] Linked creator #{creator.id} (#{creator.first_name} #{creator.last_name}) to user_id #{user_id}"
          )

          %{acc | matched: acc.matched + 1}

        {:error, changeset} ->
          Logger.warning("[SampleSync] Failed to update creator #{creator.id}: #{inspect(changeset.errors)}")
          %{acc | errors: acc.errors + 1}
      end
    end
  end

  defp build_update_attrs(creator, user_id, recipient) do
    phone = extract_phone(recipient["phone_number"])
    name = recipient["name"] || ""
    {first_name, last_name} = Creators.parse_name(name)

    %{tiktok_user_id: user_id}
    |> maybe_add_phone(creator, phone)
    |> maybe_add_name(creator, first_name, last_name)
    |> maybe_add_address(creator, recipient)
  end

  defp maybe_add_phone(attrs, creator, phone) do
    if is_nil(creator.phone) && phone && !phone_is_masked?(phone) do
      Map.merge(attrs, %{phone: phone, phone_verified: true})
    else
      attrs
    end
  end

  defp maybe_add_name(attrs, creator, first_name, last_name) do
    attrs
    |> maybe_put_if_missing(creator, :first_name, first_name)
    |> maybe_put_if_missing(creator, :last_name, last_name)
  end

  defp maybe_put_if_missing(attrs, creator, field, value) do
    current = Map.get(creator, field)

    if is_nil(current) && value && !String.contains?(value, "*") do
      Map.put(attrs, field, value)
    else
      attrs
    end
  end

  defp maybe_add_address(attrs, creator, recipient) do
    district_info = recipient["district_info"] || []

    # Extract location from district_info
    city = find_district_value(district_info, "City")
    state = find_district_value(district_info, "State")
    country = find_district_value(district_info, "Country")

    # Get street address and postal code directly from recipient
    address_line1 = recipient["address_line1"]
    postal_code = recipient["postal_code"]

    attrs =
      if should_update_field?(creator.address_line_1, address_line1) do
        Map.put(attrs, :address_line_1, address_line1)
      else
        attrs
      end

    attrs =
      if should_update_field?(creator.zipcode, postal_code) do
        Map.put(attrs, :zipcode, postal_code)
      else
        attrs
      end

    attrs =
      if should_update_field?(creator.city, city) do
        Map.put(attrs, :city, city)
      else
        attrs
      end

    attrs =
      if should_update_field?(creator.state, state) do
        Map.put(attrs, :state, state)
      else
        attrs
      end

    attrs =
      if is_nil(creator.country) && country do
        Map.put(attrs, :country, country)
      else
        attrs
      end

    attrs
  end

  # Update field if: current is nil/empty OR current is masked, AND new value is unmasked
  defp should_update_field?(current, new) do
    has_new = new && new != "" && !String.contains?(new, "*")
    needs_update = is_nil(current) || current == "" || String.contains?(current || "", "*")
    has_new && needs_update
  end

  defp find_district_value(district_info, level_name) do
    case Enum.find(district_info, fn d -> d["address_level_name"] == level_name end) do
      %{"address_name" => name} -> name
      _ -> nil
    end
  end

  defp create_creator_from_sample(user_id, recipient, acc) do
    # First check if a creator with this user_id already exists
    # (could have been created earlier in this sync from masked order data)
    case Creators.get_creator_by_tiktok_user_id(user_id) do
      %Creator{} = existing ->
        Logger.debug("[SampleSync] Found existing creator #{existing.id} with user_id #{user_id}")
        %{acc | already_linked: acc.already_linked + 1}

      nil ->
        do_create_creator_from_sample(user_id, recipient, acc)
    end
  end

  defp do_create_creator_from_sample(user_id, recipient, acc) do
    phone = extract_phone(recipient["phone_number"])
    name = recipient["name"] || ""
    {first_name, last_name} = Creators.parse_name(name)
    district_info = recipient["district_info"] || []

    # Only use unmasked data for new creators
    attrs =
      %{
        tiktok_user_id: user_id,
        country: find_district_value(district_info, "Country") || "US",
        outreach_status: "pending"
      }
      |> maybe_put(:phone, phone, &(!phone_is_masked?(&1)))
      |> maybe_put(:phone_verified, true, fn _ -> !phone_is_masked?(phone) end)
      |> maybe_put(:first_name, first_name, &(!String.contains?(&1, "*")))
      |> maybe_put(:last_name, last_name, &(!String.contains?(&1 || "", "*")))
      |> maybe_put(:address_line_1, recipient["address_line1"], &(!String.contains?(&1, "*")))
      |> maybe_put(:zipcode, recipient["postal_code"], &(!String.contains?(&1, "*")))
      |> maybe_put(:city, find_district_value(district_info, "City"), &(!String.contains?(&1, "*")))
      |> maybe_put(:state, find_district_value(district_info, "State"), &(!String.contains?(&1, "*")))

    case Creators.create_creator(attrs) do
      {:ok, creator} ->
        Logger.debug("[SampleSync] Created new creator #{creator.id} with user_id #{user_id}")
        %{acc | created: acc.created + 1}

      {:error, changeset} ->
        Logger.warning("[SampleSync] Failed to create creator: #{inspect(changeset.errors)}")
        %{acc | errors: acc.errors + 1}
    end
  end

  defp maybe_put(map, _key, nil, _validator), do: map
  defp maybe_put(map, _key, "", _validator), do: map

  defp maybe_put(map, key, value, validator) do
    if validator.(value) do
      Map.put(map, key, value)
    else
      map
    end
  end

  defp extract_phone(nil), do: nil
  defp extract_phone(""), do: nil

  defp extract_phone(phone) do
    # Normalize phone format: "(+1)8085551234" -> "+18085551234"
    phone
    |> String.replace(~r/[()]/, "")
    |> Creators.normalize_phone()
  end

  defp phone_is_masked?(nil), do: true
  defp phone_is_masked?(""), do: true
  defp phone_is_masked?(phone), do: String.contains?(phone, "*")

  defp enrich_creators(batch_size) do
    creators = get_creators_to_enrich(batch_size)
    Logger.info("Found #{length(creators)} creators to enrich")

    initial_stats = %{enriched: 0, not_found: 0, errors: 0, skipped: 0}
    stats = Enum.reduce(creators, initial_stats, &process_creator/2)

    {:ok, stats}
  end

  defp process_creator(creator, acc) do
    if is_nil(creator.tiktok_username) or creator.tiktok_username == "" do
      %{acc | skipped: acc.skipped + 1}
    else
      if acc.enriched > 0, do: Process.sleep(@api_delay_ms)
      update_stats(enrich_creator(creator), acc)
    end
  end

  defp update_stats({:ok, _}, acc), do: %{acc | enriched: acc.enriched + 1}
  defp update_stats({:error, :not_found}, acc), do: %{acc | not_found: acc.not_found + 1}
  defp update_stats({:error, _}, acc), do: %{acc | errors: acc.errors + 1}

  defp get_creators_to_enrich(limit) do
    # Prioritize:
    # 1. Creators with recent samples (last 30 days)
    # 2. Creators with no enrichment data
    # 3. Creators with stale data (>7 days)

    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30, :day)
    seven_days_ago = DateTime.add(DateTime.utc_now(), -7, :day)

    # Query creators who need enrichment, prioritized by sample recency
    query =
      from(c in Creator,
        left_join: s in assoc(c, :creator_samples),
        where: not is_nil(c.tiktok_username) and c.tiktok_username != "",
        where:
          is_nil(c.last_enriched_at) or
            c.last_enriched_at < ^seven_days_ago,
        group_by: c.id,
        order_by: [
          # Prioritize creators with recent samples
          desc: fragment("MAX(?) > ?", s.ordered_at, ^thirty_days_ago),
          # Then by whether they've never been enriched
          asc: c.last_enriched_at,
          # Then by total GMV (enrich higher-value creators first)
          desc: c.total_gmv_cents
        ],
        limit: ^limit,
        select: c
      )

    Repo.all(query)
  end

  defp enrich_creator(creator) do
    username = creator.tiktok_username

    case TiktokShop.search_marketplace_creators(keyword: username) do
      {:ok, %{creators: creators}} ->
        # Find exact match by username
        case find_exact_match(creators, username) do
          nil ->
            Logger.debug("No marketplace match for @#{username}")
            {:error, :not_found}

          marketplace_creator ->
            update_creator_from_marketplace(creator, marketplace_creator)
        end

      {:error, reason} ->
        Logger.warning("Marketplace search failed for @#{username}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp find_exact_match(creators, username) do
    normalized_username = String.downcase(username)

    Enum.find(creators, fn c ->
      c_username = c["username"] || ""
      String.downcase(c_username) == normalized_username
    end)
  end

  defp update_creator_from_marketplace(creator, marketplace_data) do
    # Extract metrics from marketplace response
    attrs = %{
      follower_count: marketplace_data["follower_count"],
      tiktok_nickname: marketplace_data["nickname"],
      tiktok_avatar_url: get_in(marketplace_data, ["avatar", "url"]),
      last_enriched_at: DateTime.utc_now(),
      enrichment_source: "marketplace_api"
    }

    # Parse GMV if available
    attrs =
      case marketplace_data["gmv"] do
        %{"amount" => amount, "currency" => "USD"} when is_binary(amount) ->
          {gmv_dollars, _} = Float.parse(amount)
          gmv_cents = round(gmv_dollars * 100)
          Map.put(attrs, :total_gmv_cents, gmv_cents)

        _ ->
          attrs
      end

    # Parse video GMV if available
    attrs =
      case marketplace_data["video_gmv"] do
        %{"amount" => amount, "currency" => "USD"} when is_binary(amount) ->
          {gmv_dollars, _} = Float.parse(amount)
          gmv_cents = round(gmv_dollars * 100)
          Map.put(attrs, :video_gmv_cents, gmv_cents)

        _ ->
          attrs
      end

    # Store avg video views if available
    attrs =
      if avg_views = marketplace_data["avg_ec_video_view_count"] do
        Map.put(attrs, :avg_video_views, avg_views)
      else
        attrs
      end

    case Creators.update_creator(creator, attrs) do
      {:ok, updated_creator} ->
        # Also create a performance snapshot for historical tracking
        create_enrichment_snapshot(updated_creator, marketplace_data)
        Logger.debug("Enriched @#{creator.tiktok_username}: #{attrs[:follower_count]} followers, $#{(attrs[:total_gmv_cents] || 0) / 100} GMV")
        {:ok, updated_creator}

      {:error, changeset} ->
        Logger.warning("Failed to update creator @#{creator.tiktok_username}: #{inspect(changeset.errors)}")
        {:error, :update_failed}
    end
  end

  defp create_enrichment_snapshot(creator, marketplace_data) do
    # Create a performance snapshot for historical tracking
    attrs = %{
      creator_id: creator.id,
      snapshot_date: Date.utc_today(),
      source: "marketplace_api",
      follower_count: marketplace_data["follower_count"]
    }

    # Add GMV if available
    attrs =
      case marketplace_data["gmv"] do
        %{"amount" => amount, "currency" => "USD"} when is_binary(amount) ->
          {gmv_dollars, _} = Float.parse(amount)
          gmv_cents = round(gmv_dollars * 100)
          Map.put(attrs, :gmv_cents, gmv_cents)

        _ ->
          attrs
      end

    case Creators.create_performance_snapshot(attrs) do
      {:ok, _snapshot} -> :ok
      {:error, _} -> :ok  # Snapshot creation failure shouldn't fail enrichment
    end
  end
end
