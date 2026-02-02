defmodule Pavoi.ProductSets do
  @moduledoc """
  The ProductSets context handles product sets, product set products, and real-time state management.
  """

  import Ecto.Query, warn: false
  alias Pavoi.Repo

  alias Pavoi.Catalog.{ProductImage, ProductVariant}
  alias Pavoi.ProductSets.{MessagePreset, ProductSet, ProductSetProduct, ProductSetState}

  # Default color for host messages
  @default_message_color "amber"

  @doc """
  Returns the default color for host messages.
  """
  def default_message_color, do: @default_message_color

  ## Product Sets

  @doc """
  Returns the list of product sets.
  """
  def list_product_sets do
    Repo.all(ProductSet)
  end

  @doc """
  Returns the list of product sets with brands and products preloaded, ordered by most recently modified.
  """
  def list_product_sets_with_details do
    ordered_images = from(pi in ProductImage, order_by: [asc: pi.position])
    ordered_variants = from(pv in ProductVariant, order_by: [asc: pv.position])

    ProductSet
    |> order_by([ps], desc: ps.updated_at)
    |> preload([
      :brand,
      product_set_products: [
        product: [
          product_images: ^ordered_images,
          product_variants: ^ordered_variants
        ]
      ]
    ])
    |> Repo.all()
  end

  @doc """
  Returns a paginated list of product sets with brands and products preloaded, ordered by most recently modified.

  ## Options
    * `:page` - The page number to fetch (default: 1)
    * `:per_page` - Number of product sets per page (default: 20)
    * `:search_query` - Optional search query to filter by name or notes (default: "")

  ## Returns
  A map with the following keys:
    * `:product_sets` - List of product set structs with preloaded associations
    * `:page` - Current page number
    * `:per_page` - Number of product sets per page
    * `:total` - Total count of product sets
    * `:has_more` - Boolean indicating if there are more product sets to load
  """
  def list_product_sets_with_details_paginated(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    search_query = Keyword.get(opts, :search_query, "")

    ordered_images = from(pi in ProductImage, order_by: [asc: pi.position])
    ordered_variants = from(pv in ProductVariant, order_by: [asc: pv.position])

    base_query =
      ProductSet
      |> order_by([ps], desc: ps.updated_at)

    # Apply search filter if provided
    base_query =
      if search_query != "" do
        search_pattern = "%#{search_query}%"

        where(
          base_query,
          [ps],
          ilike(ps.name, ^search_pattern) or ilike(ps.notes, ^search_pattern)
        )
      else
        base_query
      end

    total = Repo.aggregate(base_query, :count)

    product_sets =
      base_query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> preload([
        :brand,
        product_set_streams: :stream,
        product_set_products: [
          product: [
            product_images: ^ordered_images,
            product_variants: ^ordered_variants
          ]
        ]
      ])
      |> Repo.all()

    %{
      product_sets: product_sets,
      page: page,
      per_page: per_page,
      total: total,
      has_more: total > page * per_page
    }
  end

  @doc """
  Gets a single product set.
  Raises `Ecto.NoResultsError` if the ProductSet does not exist.
  """
  def get_product_set!(id) do
    ordered_images = from(pi in ProductImage, order_by: [asc: pi.position])

    ProductSet
    |> preload([
      :brand,
      product_set_products: [product: [:brand, product_images: ^ordered_images]]
    ])
    |> Repo.get!(id)
  end

  @doc """
  Gets a product set by slug.
  """
  def get_product_set_by_slug!(slug) do
    ordered_images = from(pi in ProductImage, order_by: [asc: pi.position])

    ProductSet
    |> where([ps], ps.slug == ^slug)
    |> preload(product_set_products: [product: [:brand, product_images: ^ordered_images]])
    |> Repo.one!()
  end

  @doc """
  Checks if a product set with the given name already exists for a brand.
  """
  def product_set_name_exists?(name, brand_id) when is_binary(name) and not is_nil(brand_id) do
    slug = slugify(name)

    Repo.exists?(
      from ps in ProductSet,
        where: ps.brand_id == ^brand_id and ps.slug == ^slug
    )
  end

  def product_set_name_exists?(_, _), do: false

  @doc """
  Creates a product set.
  """
  def create_product_set(attrs \\ %{}) do
    %ProductSet{}
    |> ProductSet.changeset(attrs)
    |> Repo.insert()
    |> broadcast_product_set_list_change()
  end

  @doc """
  Creates a product set with products in a single transaction.

  Takes product set attributes and a list of product IDs. Creates the product set
  and then adds each product as a product_set_product with sequential positions.

  Returns {:ok, product_set} or {:error, changeset} on failure.
  """
  def create_product_set_with_products(product_set_attrs, product_ids \\ []) do
    Repo.transaction(fn ->
      with {:ok, product_set} <- create_product_set(product_set_attrs),
           :ok <- add_products_to_product_set(product_set.id, product_ids) do
        product_set
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp add_products_to_product_set(product_set_id, product_ids) do
    Enum.with_index(product_ids, 1)
    |> Enum.reduce_while(:ok, fn {product_id, position}, _acc ->
      case add_product_to_product_set(product_set_id, product_id, %{position: position}) do
        {:ok, _} -> {:cont, :ok}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  @doc """
  Duplicates an existing product set with all its products.

  Creates a new product set with the same brand, notes, and product lineup as the original.
  The new product set will have "Copy of " prepended to its name and a unique slug.
  All product set products are duplicated with their positions, sections, featured overrides, and notes.

  Returns {:ok, product_set} or {:error, changeset}.
  """
  def duplicate_product_set(product_set_id) do
    Repo.transaction(fn ->
      # Load the original product set with products
      original_product_set = get_product_set!(product_set_id)

      # Generate new name and slug
      new_name = "Copy of #{original_product_set.name}"
      new_slug = generate_unique_slug(new_name)

      # Create new product set with same attributes
      product_set_attrs = %{
        brand_id: original_product_set.brand_id,
        name: new_name,
        slug: new_slug,
        notes: original_product_set.notes
      }

      # Create the new product set
      with {:ok, new_product_set} <- create_product_set(product_set_attrs),
           :ok <-
             duplicate_product_set_products(
               original_product_set.product_set_products,
               new_product_set.id
             ) do
        new_product_set
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  # Duplicates all product set products from the source product set to a new product set.
  # Copies all product associations including positions, overrides, and notes.
  # Returns :ok if all products are duplicated successfully, or {:error, changeset}
  # on the first failure. Uses reduce_while for early exit on error.
  defp duplicate_product_set_products(product_set_products, new_product_set_id) do
    product_set_products
    |> Enum.reduce_while(:ok, fn psp, _acc ->
      attrs = %{
        product_set_id: new_product_set_id,
        product_id: psp.product_id,
        position: psp.position,
        section: psp.section,
        featured_name: psp.featured_name,
        featured_talking_points_md: psp.featured_talking_points_md,
        featured_original_price_cents: psp.featured_original_price_cents,
        featured_sale_price_cents: psp.featured_sale_price_cents,
        notes: psp.notes
      }

      case Repo.insert(ProductSetProduct.changeset(%ProductSetProduct{}, attrs)) do
        {:ok, _} -> {:cont, :ok}
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp generate_unique_slug(name) do
    base_slug = slugify(name)
    ensure_unique_slug(base_slug, 0)
  end

  # Recursively ensures a slug is unique by appending a numeric suffix if needed.
  # On the first attempt (0), tries the base slug. If taken, appends -1, -2, etc.
  # Returns the first available slug. Example: "my-product-set" -> "my-product-set-2"
  defp ensure_unique_slug(base_slug, attempt) do
    slug = if attempt == 0, do: base_slug, else: "#{base_slug}-#{attempt}"

    case Repo.get_by(ProductSet, slug: slug) do
      nil -> slug
      _ -> ensure_unique_slug(base_slug, attempt + 1)
    end
  end

  @doc """
  Converts a name string into a URL-friendly slug.

  Returns a lowercase string with spaces replaced by hyphens and special
  characters removed. Falls back to a timestamp-based slug if the result is empty.

  ## Examples

      iex> ProductSets.slugify("My Product Set Name")
      "my-product-set-name"

      iex> ProductSets.slugify("@#$%")
      "product-set-1234567890"
  """
  def slugify(name) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^\w\s-]/, "")
      |> String.replace(~r/\s+/, "-")
      |> String.trim("-")

    # Fallback for empty slugs
    if slug == "", do: "product-set-#{:os.system_time(:second)}", else: slug
  end

  @doc """
  Updates a product set.
  """
  def update_product_set(%ProductSet{} = product_set, attrs) do
    product_set
    |> ProductSet.changeset(attrs)
    |> Repo.update()
    |> broadcast_product_set_list_change()
  end

  @doc """
  Deletes a product set.
  """
  def delete_product_set(%ProductSet{} = product_set) do
    Repo.delete(product_set)
    |> broadcast_product_set_list_change()
  end

  # Updates a product set's updated_at timestamp to the current time.
  # This is useful to mark a product set as recently modified when its products change.
  defp touch_product_set(product_set_id) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    from(ps in ProductSet, where: ps.id == ^product_set_id)
    |> Repo.update_all(set: [updated_at: now])
  end

  ## Product Set Products

  @doc """
  Gets a single product set product.
  """
  def get_product_set_product!(id) do
    ordered_images = from(pi in ProductImage, order_by: [asc: pi.position])
    ordered_variants = from(pv in ProductVariant, order_by: [asc: pv.position])

    ProductSetProduct
    |> preload(
      product: [:brand, product_images: ^ordered_images, product_variants: ^ordered_variants]
    )
    |> Repo.get!(id)
  end

  @doc """
  Adds a product to a product set with the given position and optional overrides.
  Also updates the product set's updated_at timestamp to mark it as recently modified.
  """
  def add_product_to_product_set(product_set_id, product_id, attrs \\ %{}) do
    attrs =
      attrs
      |> Map.put(:product_set_id, product_set_id)
      |> Map.put(:product_id, product_id)

    result =
      %ProductSetProduct{}
      |> ProductSetProduct.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, _} -> touch_product_set(product_set_id)
      error -> error
    end

    result
    |> broadcast_product_set_list_change()
  end

  @doc """
  Removes a product from a product set by deleting the product_set_product record.
  Automatically renumbers remaining products to fill any gaps and keep positions sequential.
  Also updates the product set's updated_at timestamp to mark it as recently modified.
  """
  def remove_product_from_product_set(product_set_product_id) do
    case Repo.get(ProductSetProduct, product_set_product_id) do
      nil ->
        {:error, :not_found}

      product_set_product ->
        result = Repo.delete(product_set_product)

        case result do
          {:ok, _} ->
            # Auto-renumber positions to fill gaps
            renumber_product_set_products(product_set_product.product_set_id)

            result
            |> broadcast_product_set_list_change()

          error ->
            error
        end
    end
  end

  @doc """
  Reorders product set products based on a list of product_set_product IDs.

  Takes a product_set_id and a list of product_set_product IDs in the desired order.
  Updates the position field for each product_set_product efficiently using batch updates.

  Returns {:ok, count} where count is the number of updated records, or
  {:error, reason} if validation fails.
  """
  def reorder_products(product_set_id, ordered_product_set_product_ids) do
    # Validate input
    with {:ok, _product_set} <- validate_product_set_exists(product_set_id),
         :ok <- validate_no_duplicates(ordered_product_set_product_ids),
         {:ok, valid_ids} <-
           validate_product_set_product_ownership(product_set_id, ordered_product_set_product_ids) do
      # Proceed with reordering
      result =
        Repo.transaction(fn ->
          # Step 1: Move all products to temporary positions to avoid constraint violations
          # Use a high offset (10000) to ensure no conflicts with existing positions
          valid_ids
          |> Enum.with_index(1)
          |> Enum.each(fn {product_set_product_id, index} ->
            temp_position = 10_000 + index

            from(psp in ProductSetProduct,
              where: psp.id == ^product_set_product_id and psp.product_set_id == ^product_set_id
            )
            |> Repo.update_all(set: [position: temp_position])
          end)

          # Step 2: Update each product to its final position
          count =
            valid_ids
            # Start positions at 1
            |> Enum.with_index(1)
            |> Enum.map(fn {product_set_product_id, new_position} ->
              from(psp in ProductSetProduct,
                where: psp.id == ^product_set_product_id and psp.product_set_id == ^product_set_id
              )
              |> Repo.update_all(set: [position: new_position])
              # Returns {count, nil}, we want count
              |> elem(0)
            end)
            |> Enum.sum()

          # Touch the product set to update its modified timestamp
          touch_product_set(product_set_id)

          count
        end)

      case result do
        {:ok, count} ->
          broadcast_product_set_list_change({:ok, count})
          {:ok, count}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate_product_set_exists(product_set_id) do
    case Repo.get(ProductSet, product_set_id) do
      nil -> {:error, :product_set_not_found}
      product_set -> {:ok, product_set}
    end
  end

  defp validate_no_duplicates(ids) do
    if length(ids) == length(Enum.uniq(ids)) do
      :ok
    else
      {:error, :duplicate_ids}
    end
  end

  defp validate_product_set_product_ownership(product_set_id, product_set_product_ids) do
    # Query all product_set_products that match the provided IDs and belong to the product set
    valid_ids =
      from(psp in ProductSetProduct,
        where: psp.product_set_id == ^product_set_id and psp.id in ^product_set_product_ids,
        select: psp.id
      )
      |> Repo.all()

    if length(valid_ids) == length(product_set_product_ids) do
      {:ok, product_set_product_ids}
    else
      {:error, :invalid_product_set_product_ids}
    end
  end

  @doc """
  Gets the next available position for a product set.
  Uses database query to avoid race conditions.
  """
  def get_next_position_for_product_set(product_set_id) do
    max_position =
      from(psp in ProductSetProduct,
        where: psp.product_set_id == ^product_set_id,
        select: max(psp.position)
      )
      |> Repo.one()

    (max_position || 0) + 1
  end

  @doc """
  Gets adjacent product set products (for preloading).
  Returns products at positions: current_position ± range.
  """
  def get_adjacent_product_set_products(product_set_id, current_position, range \\ 2) do
    ordered_images = from(pi in ProductImage, order_by: [asc: pi.position])

    from(psp in ProductSetProduct,
      where:
        psp.product_set_id == ^product_set_id and
          psp.position >= ^(current_position - range) and
          psp.position <= ^(current_position + range),
      order_by: [asc: psp.position],
      preload: [product: [:brand, product_images: ^ordered_images]]
    )
    |> Repo.all()
  end

  ## Undo Operations

  @doc """
  Gets a product set product with all fields needed for undo restoration.
  Returns a map with all the data needed to restore the product if deleted.
  Returns nil if not found.
  """
  def get_product_set_product_for_undo(id) do
    case Repo.get(ProductSetProduct, id) do
      nil ->
        nil

      psp ->
        %{
          product_set_id: psp.product_set_id,
          product_id: psp.product_id,
          position: psp.position,
          section: psp.section,
          featured_name: psp.featured_name,
          featured_talking_points_md: psp.featured_talking_points_md,
          featured_original_price_cents: psp.featured_original_price_cents,
          featured_sale_price_cents: psp.featured_sale_price_cents,
          notes: psp.notes
        }
    end
  end

  @doc """
  Gets the current product order for a product set.
  Returns a list of product_set_product IDs in position order.
  """
  def get_current_product_order(product_set_id) do
    from(psp in ProductSetProduct,
      where: psp.product_set_id == ^product_set_id,
      order_by: [asc: psp.position],
      select: psp.id
    )
    |> Repo.all()
  end

  @doc """
  Removes a product from a product set silently (no broadcast).
  Used for batch undo operations where we broadcast once at the end.
  Returns {:ok, product_set_product} or {:error, reason}.
  """
  def remove_product_from_product_set_silent(product_set_product_id) do
    case Repo.get(ProductSetProduct, product_set_product_id) do
      nil ->
        {:error, :not_found}

      product_set_product ->
        case Repo.delete(product_set_product) do
          {:ok, deleted} ->
            # Renumber positions silently (don't broadcast)
            renumber_product_set_products_silent(product_set_product.product_set_id)
            {:ok, deleted}

          error ->
            error
        end
    end
  end

  @doc """
  Restores a product to a product set with all original data.
  Shifts existing products at and after the target position to make room.
  Returns {:ok, product_set_product} or {:error, changeset}.
  """
  def restore_product_to_product_set(psp_data) do
    Repo.transaction(fn ->
      # First, shift existing products at and after the target position
      shift_products_for_insertion(psp_data.product_set_id, psp_data.position)

      # Insert the product at its original position
      attrs = %{
        product_set_id: psp_data.product_set_id,
        product_id: psp_data.product_id,
        position: psp_data.position,
        section: psp_data.section,
        featured_name: psp_data.featured_name,
        featured_talking_points_md: psp_data.featured_talking_points_md,
        featured_original_price_cents: psp_data.featured_original_price_cents,
        featured_sale_price_cents: psp_data.featured_sale_price_cents,
        notes: psp_data.notes
      }

      case %ProductSetProduct{}
           |> ProductSetProduct.changeset(attrs)
           |> Repo.insert() do
        {:ok, psp} ->
          touch_product_set(psp_data.product_set_id)
          psp

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, psp} ->
        broadcast_product_set_list_change({:ok, psp})

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Shifts products at and after the given position to make room for insertion.
  # Uses a two-phase approach to avoid unique constraint violations:
  # 1. Move affected products to temporary high positions
  # 2. Move them to their final positions (original + 1)
  defp shift_products_for_insertion(product_set_id, target_position) do
    # Get products that need to be shifted, ordered by position descending
    # so we can update them from highest to lowest
    products_to_shift =
      from(psp in ProductSetProduct,
        where: psp.product_set_id == ^product_set_id and psp.position >= ^target_position,
        order_by: [desc: psp.position],
        select: {psp.id, psp.position}
      )
      |> Repo.all()

    # Phase 1: Move all to temporary positions (add 10000)
    Enum.each(products_to_shift, fn {id, position} ->
      from(psp in ProductSetProduct, where: psp.id == ^id)
      |> Repo.update_all(set: [position: position + 10_000])
    end)

    # Phase 2: Move to final positions (original + 1)
    Enum.each(products_to_shift, fn {id, position} ->
      from(psp in ProductSetProduct, where: psp.id == ^id)
      |> Repo.update_all(set: [position: position + 1])
    end)
  end

  # Renumbers product positions without broadcasting (for batch operations)
  defp renumber_product_set_products_silent(product_set_id) do
    product_set_products =
      from(psp in ProductSetProduct,
        where: psp.product_set_id == ^product_set_id,
        order_by: [asc: psp.position]
      )
      |> Repo.all()

    # Update positions sequentially, starting from 1
    product_set_products
    |> Enum.with_index(1)
    |> Enum.each(fn {psp, new_position} ->
      if psp.position != new_position do
        psp
        |> Ecto.Changeset.change(position: new_position)
        |> Repo.update!()
      end
    end)

    touch_product_set(product_set_id)
  end

  ## Product Set State Management

  @doc """
  Gets the current product set state.
  """
  def get_product_set_state(product_set_id) do
    case Repo.get_by(ProductSetState, product_set_id: product_set_id) do
      nil ->
        {:error, :not_found}

      state ->
        # Preload with ordered images
        state =
          state
          |> Repo.preload(current_product_set_product: [product: :brand])
          |> Repo.preload(
            current_product_set_product: [
              product: [product_images: from(pi in ProductImage, order_by: [asc: pi.position])]
            ]
          )

        {:ok, state}
    end
  end

  @doc """
  Initializes product set state to the first product.
  Uses upsert to handle cases where state row already exists.
  """
  def initialize_product_set_state(product_set_id) do
    # Get first product set product
    first_psp =
      from(psp in ProductSetProduct,
        where: psp.product_set_id == ^product_set_id,
        order_by: [asc: psp.position],
        limit: 1
      )
      |> Repo.one()

    if first_psp do
      %ProductSetState{}
      |> ProductSetState.changeset(%{
        product_set_id: product_set_id,
        current_product_set_product_id: first_psp.id,
        current_image_index: 0
      })
      |> Repo.insert(
        on_conflict:
          {:replace, [:current_product_set_product_id, :current_image_index, :updated_at]},
        conflict_target: :product_set_id
      )
      |> broadcast_state_change()
    else
      {:error, :no_products}
    end
  end

  @doc """
  PRIMARY NAVIGATION: Jumps directly to a product by its position number.
  This is the main navigation method for the host view.
  """
  def jump_to_product(product_set_id, position) do
    case Repo.get_by(ProductSetProduct, product_set_id: product_set_id, position: position) do
      nil ->
        {:error, :invalid_position}

      psp ->
        update_product_set_state(product_set_id, %{
          current_product_set_product_id: psp.id,
          current_image_index: 0
        })
    end
  end

  @doc """
  CONVENIENCE: Advances to the next product in sequence.
  Used for arrow key navigation, not the primary method.
  """
  def advance_to_next_product(product_set_id) do
    with {:ok, current_state} <- get_product_set_state(product_set_id),
         {:ok, current_psp} <- get_current_product_set_product(current_state),
         {:ok, next_psp} <- get_next_product_set_product(product_set_id, current_psp.position) do
      update_product_set_state(product_set_id, %{
        current_product_set_product_id: next_psp.id,
        current_image_index: 0
      })
    else
      {:error, :no_next_product} -> {:error, :end_of_product_set}
      error -> error
    end
  end

  @doc """
  CONVENIENCE: Goes to the previous product in sequence.
  Used for arrow key navigation, not the primary method.
  """
  def go_to_previous_product(product_set_id) do
    with {:ok, current_state} <- get_product_set_state(product_set_id),
         {:ok, current_psp} <- get_current_product_set_product(current_state),
         {:ok, prev_psp} <- get_previous_product_set_product(product_set_id, current_psp.position) do
      update_product_set_state(product_set_id, %{
        current_product_set_product_id: prev_psp.id,
        current_image_index: 0
      })
    else
      {:error, :no_previous_product} -> {:error, :start_of_product_set}
      error -> error
    end
  end

  @doc """
  Cycles through product images (next or previous).
  """
  def cycle_product_image(product_set_id, direction) do
    with {:ok, state} <- get_product_set_state(product_set_id),
         {:ok, psp} <- get_current_product_set_product(state),
         product <- Repo.preload(psp.product, :product_images),
         image_count when image_count > 0 <- length(product.product_images) do
      new_index =
        case direction do
          :next -> rem(state.current_image_index + 1, image_count)
          :previous -> rem(state.current_image_index - 1 + image_count, image_count)
        end

      update_product_set_state(product_set_id, %{current_image_index: new_index})
    else
      0 -> {:error, :no_images}
      error -> error
    end
  end

  @doc """
  Sets the current image index directly for the product set.
  Used when clicking on a thumbnail to jump to a specific image.
  """
  def set_image_index(product_set_id, index) when is_integer(index) and index >= 0 do
    with {:ok, state} <- get_product_set_state(product_set_id),
         {:ok, psp} <- get_current_product_set_product(state),
         product <- Repo.preload(psp.product, :product_images),
         image_count when image_count > 0 <- length(product.product_images),
         true <- index < image_count do
      update_product_set_state(product_set_id, %{current_image_index: index})
    else
      0 -> {:error, :no_images}
      false -> {:error, :invalid_index}
      error -> error
    end
  end

  ## Host Messages

  @doc """
  Sends a message to the host by updating the product set state.
  The message is persisted in the database and broadcast to all connected clients.
  """
  def send_host_message(product_set_id, message_text, color \\ @default_message_color) do
    message_id = generate_message_id()
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

    update_product_set_state(product_set_id, %{
      current_host_message_text: message_text,
      current_host_message_id: message_id,
      current_host_message_timestamp: timestamp,
      current_host_message_color: color
    })
  end

  @doc """
  Clears the current host message from the product set state.
  """
  def clear_host_message(product_set_id) do
    update_product_set_state(product_set_id, %{
      current_host_message_text: nil,
      current_host_message_id: nil,
      current_host_message_timestamp: nil,
      current_host_message_color: nil
    })
  end

  ## Message Presets

  @doc """
  Returns the list of message presets, ordered by position.
  """
  def list_message_presets do
    MessagePreset
    |> order_by([mp], asc: mp.position)
    |> Repo.all()
  end

  @doc """
  Gets a single message preset.

  Raises `Ecto.NoResultsError` if the message preset does not exist.
  """
  def get_message_preset!(id), do: Repo.get!(MessagePreset, id)

  @doc """
  Creates a message preset.
  """
  def create_message_preset(attrs \\ %{}) do
    # If no position provided, set it to be last
    attrs =
      if Map.has_key?(attrs, :position) or Map.has_key?(attrs, "position") do
        attrs
      else
        max_position =
          MessagePreset
          |> select([mp], max(mp.position))
          |> Repo.one()

        Map.put(attrs, :position, (max_position || 0) + 1)
      end

    %MessagePreset{}
    |> MessagePreset.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a message preset.
  """
  def delete_message_preset(%MessagePreset{} = message_preset) do
    Repo.delete(message_preset)
  end

  @doc """
  Renumbers product set product positions to be sequential starting from 1.
  Useful after deleting products that leave gaps in numbering.
  Also updates the product set's updated_at timestamp to mark it as recently modified.
  """
  def renumber_product_set_products(product_set_id) do
    product_set_products =
      from(psp in ProductSetProduct,
        where: psp.product_set_id == ^product_set_id,
        order_by: [asc: psp.position]
      )
      |> Repo.all()

    Repo.transaction(fn ->
      # Update positions sequentially, starting from 1
      updated_count =
        product_set_products
        |> Enum.with_index(1)
        |> Enum.count(fn {psp, new_position} ->
          update_product_set_product_position({psp, new_position}) != :ok
        end)

      # Touch product set to update its timestamp
      touch_product_set(product_set_id)

      {:ok, updated_count}
    end)
    |> case do
      {:ok, {:ok, count}} -> {:ok, count}
      {:error, reason} -> {:error, reason}
    end
  end

  defp update_product_set_product_position({psp, new_position})
       when psp.position != new_position do
    psp
    |> Ecto.Changeset.change(position: new_position)
    |> Repo.update!()
  end

  defp update_product_set_product_position(_), do: :ok

  ## Private Helpers

  defp update_product_set_state(product_set_id, attrs) do
    Repo.transaction(fn ->
      # Lock the row to prevent concurrent updates
      state =
        from(pss in ProductSetState,
          where: pss.product_set_id == ^product_set_id,
          lock: "FOR UPDATE"
        )
        |> Repo.one!()
        |> ProductSetState.changeset(attrs)
        |> Repo.update!()

      broadcast_state_change({:ok, state})
      state
    end)
    |> case do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:error, reason}
    end
  end

  defp broadcast_state_change({:ok, %ProductSetState{} = state}) do
    Phoenix.PubSub.broadcast(
      Pavoi.PubSub,
      "product_set:#{state.product_set_id}:state",
      {:state_changed, state}
    )

    {:ok, state}
  end

  defp broadcast_state_change(error), do: error

  defp broadcast_product_set_list_change(result) do
    case result do
      {:ok, _} ->
        Phoenix.PubSub.broadcast(
          Pavoi.PubSub,
          "product_sets:list",
          {:product_set_list_changed}
        )

        result

      error ->
        error
    end
  end

  defp get_current_product_set_product(%ProductSetState{current_product_set_product_id: nil}),
    do: {:error, :no_current_product}

  defp get_current_product_set_product(state) do
    case Repo.get(ProductSetProduct, state.current_product_set_product_id) do
      nil ->
        {:error, :not_found}

      psp ->
        # Preload with ordered images
        psp =
          psp
          |> Repo.preload(product: :brand)
          |> Repo.preload(
            product: [product_images: from(pi in ProductImage, order_by: [asc: pi.position])]
          )

        {:ok, psp}
    end
  end

  defp get_next_product_set_product(product_set_id, current_position) do
    from(psp in ProductSetProduct,
      where: psp.product_set_id == ^product_set_id and psp.position > ^current_position,
      order_by: [asc: psp.position],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :no_next_product}
      psp -> {:ok, psp}
    end
  end

  defp get_previous_product_set_product(product_set_id, current_position) do
    from(psp in ProductSetProduct,
      where: psp.product_set_id == ^product_set_id and psp.position < ^current_position,
      order_by: [desc: psp.position],
      limit: 1
    )
    |> Repo.one()
    |> case do
      nil -> {:error, :no_previous_product}
      psp -> {:ok, psp}
    end
  end

  defp generate_message_id do
    "msg_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
  end

  ## Public Sharing

  @doc """
  Generates a signed token for sharing a product set publicly.
  The token expires after 90 days.
  """
  def generate_share_token(product_set_id) do
    Phoenix.Token.sign(PavoiWeb.Endpoint, "product_set_share", product_set_id)
  end

  @doc """
  Verifies a share token and returns the product set ID.
  Returns {:ok, product_set_id} or {:error, reason}.
  """
  def verify_share_token(token) do
    # 90 days in seconds
    max_age = 90 * 24 * 60 * 60
    Phoenix.Token.verify(PavoiWeb.Endpoint, "product_set_share", token, max_age: max_age)
  end

  @doc """
  Gets a product set with products and images preloaded for public display.
  Raises `Ecto.NoResultsError` if the ProductSet does not exist.
  """
  def get_product_set_for_public!(id) do
    ordered_images = from(pi in ProductImage, order_by: [asc: pi.position])
    ordered_variants = from(pv in ProductVariant, order_by: [asc: pv.position])

    ProductSet
    |> preload([
      :brand,
      product_set_products: [
        product: [
          :brand,
          product_images: ^ordered_images,
          product_variants: ^ordered_variants
        ]
      ]
    ])
    |> Repo.get!(id)
  end
end
