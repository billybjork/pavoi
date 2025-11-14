defmodule HudsonWeb.SessionsLive.Index do
  use HudsonWeb, :live_view

  alias Hudson.Catalog
  alias Hudson.Catalog.Product
  alias Hudson.Sessions
  alias Hudson.Sessions.{Session, SessionProduct}

  import HudsonWeb.ProductComponents

  @impl true
  def mount(_params, _session, socket) do
    sessions = Sessions.list_sessions_with_details()
    brands = Catalog.list_brands()

    socket =
      socket
      |> assign(:sessions, sessions)
      |> assign(:brands, brands)
      |> assign(:expanded_session_ids, MapSet.new())
      |> assign(:selected_session_for_product, nil)
      |> assign(:available_products, [])
      |> assign(:show_modal_for_session, nil)
      |> assign(:show_new_session_modal, false)
      |> assign(:editing_product, nil)
      |> assign(
        :product_form,
        to_form(SessionProduct.changeset(%SessionProduct{}, %{}))
      )
      |> assign(
        :session_form,
        to_form(Session.changeset(%Session{}, %{}))
      )
      |> assign(
        :product_edit_form,
        to_form(Product.changeset(%Product{}, %{}))
      )
      |> assign(:product_search_query, "")
      |> assign(:product_page, 1)
      |> assign(:product_total_count, 0)
      |> assign(:selected_product_ids, MapSet.new())
      |> assign(:new_session_products, [])
      |> assign(:new_session_has_more, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("keydown", %{"key" => "Escape"}, socket) do
    # Only close expanded sessions if no modal is currently open
    # If a modal is open, let the modal's own Escape handler close it first
    modal_open? =
      socket.assigns.show_new_session_modal or socket.assigns.selected_session_for_product != nil or
        socket.assigns.editing_product != nil

    if modal_open? do
      {:noreply, socket}
    else
      # Close all expanded sessions on Escape
      {:noreply, assign(socket, :expanded_session_ids, MapSet.new())}
    end
  end

  @impl true
  def handle_event("toggle_expand", %{"session-id" => session_id}, socket) do
    session_id = normalize_id(session_id)
    expanded = socket.assigns.expanded_session_ids

    new_expanded =
      if MapSet.member?(expanded, session_id) do
        MapSet.delete(expanded, session_id)
      else
        MapSet.put(expanded, session_id)
      end

    {:noreply, assign(socket, :expanded_session_ids, new_expanded)}
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    # No-op handler to prevent event bubbling to parent elements
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_products_for_session", %{"session-id" => session_id}, socket) do
    session_id = normalize_id(session_id)
    session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))

    # Get products for this session's brand
    products = Catalog.list_products_by_brand_with_images(session.brand_id)

    # Get next position from database (avoids race conditions)
    next_position = Sessions.get_next_position_for_session(session_id)

    # Create a changeset with default position
    changeset =
      SessionProduct.changeset(%SessionProduct{}, %{
        "session_id" => session_id,
        "position" => next_position
      })

    socket =
      socket
      |> assign(:selected_session_for_product, session)
      |> assign(:available_products, products)
      |> assign(:product_form, to_form(changeset))

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_product", %{"session_product" => params}, socket) do
    changeset =
      %SessionProduct{}
      |> SessionProduct.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :product_form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate_product", %{"product" => product_params}, socket) do
    changeset =
      socket.assigns.editing_product
      |> Product.changeset(product_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :product_edit_form, to_form(changeset))}
  end

  @impl true
  def handle_event("close_product_modal", _params, socket) do
    socket =
      socket
      |> assign(:selected_session_for_product, nil)
      |> assign(:show_modal_for_session, nil)
      |> assign(
        :product_form,
        to_form(SessionProduct.changeset(%SessionProduct{}, %{}))
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_new_session_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_new_session_modal, true)
      |> assign(:product_search_query, "")
      |> assign(:product_page, 1)
      |> assign(:selected_product_ids, MapSet.new())
      |> assign(:new_session_products, [])
      |> assign(:new_session_has_more, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_new_session_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_new_session_modal, false)
      |> assign(
        :session_form,
        to_form(Session.changeset(%Session{}, %{}))
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_session", %{"session" => params}, socket) do
    changeset =
      %Session{}
      |> Session.changeset(params)
      |> Map.put(:action, :validate)

    socket =
      socket
      |> assign(:session_form, to_form(changeset))

    # If brand changed, reload products
    socket =
      if params["brand_id"] && params["brand_id"] != "" do
        load_products_for_new_session(socket)
      else
        socket
        |> assign(:new_session_products, [])
        |> assign(:new_session_has_more, false)
        |> assign(:product_search_query, "")
        |> assign(:selected_product_ids, MapSet.new())
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_session", %{"session" => session_params}, socket) do
    # Generate slug from name
    slug = slugify(session_params["name"])
    session_params = Map.put(session_params, "slug", slug)

    # Extract selected product IDs (as list in order)
    selected_ids = MapSet.to_list(socket.assigns.selected_product_ids)

    case Sessions.create_session_with_products(session_params, selected_ids) do
      {:ok, _session} ->
        # Preserve expanded state across reload
        expanded_ids = socket.assigns.expanded_session_ids
        sessions = Sessions.list_sessions_with_details()

        socket =
          socket
          |> assign(:sessions, sessions)
          |> assign(:expanded_session_ids, expanded_ids)
          |> assign(:show_new_session_modal, false)
          |> assign(
            :session_form,
            to_form(Session.changeset(%Session{}, %{}))
          )
          |> assign(:product_search_query, "")
          |> assign(:product_page, 1)
          |> assign(:selected_product_ids, MapSet.new())
          |> assign(:new_session_products, [])
          |> assign(:new_session_has_more, false)
          |> put_flash(:info, "Session created successfully")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign(:session_form, to_form(changeset))
          |> put_flash(:error, "Please fix the errors below")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save_product_to_session", %{"session_product" => params}, socket) do
    # Convert string params to integers
    session_id = String.to_integer(params["session_id"])
    product_id = String.to_integer(params["product_id"])
    position = String.to_integer(params["position"])

    case Sessions.add_product_to_session(session_id, product_id, %{position: position}) do
      {:ok, _session_product} ->
        # Preserve expanded state across reload
        expanded_ids = socket.assigns.expanded_session_ids
        sessions = Sessions.list_sessions_with_details()

        # Reset form and close modal
        socket =
          socket
          |> assign(:sessions, sessions)
          |> assign(:expanded_session_ids, expanded_ids)
          |> assign(:selected_session_for_product, nil)
          |> assign(:show_modal_for_session, nil)
          |> assign(
            :product_form,
            to_form(SessionProduct.changeset(%SessionProduct{}, %{}))
          )
          |> put_flash(:info, "Product added to session")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Keep modal open, show errors in form
        socket =
          socket
          |> assign(:product_form, to_form(changeset))
          |> put_flash(:error, "Please fix the errors below")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("remove_product", %{"session-product-id" => sp_id}, socket) do
    sp_id = normalize_id(sp_id)

    case Sessions.remove_product_from_session(sp_id) do
      {:ok, _session_product} ->
        # Preserve expanded state across reload
        expanded_ids = socket.assigns.expanded_session_ids
        sessions = Sessions.list_sessions_with_details()

        socket =
          socket
          |> assign(:sessions, sessions)
          |> assign(:expanded_session_ids, expanded_ids)
          |> put_flash(:info, "Product removed from session")

        {:noreply, socket}

      {:error, :not_found} ->
        socket
        |> put_flash(:error, "Product not found in session")
        |> then(&{:noreply, &1})

      {:error, reason} ->
        socket
        |> put_flash(:error, "Failed to remove product: #{inspect(reason)}")
        |> then(&{:noreply, &1})
    end
  end

  @impl true
  def handle_event("delete_session", %{"session-id" => session_id}, socket) do
    session_id = normalize_id(session_id)
    session = Sessions.get_session!(session_id)

    case Sessions.delete_session(session) do
      {:ok, _session} ->
        # Preserve expanded state across reload (and remove deleted session)
        expanded_ids = MapSet.delete(socket.assigns.expanded_session_ids, session_id)
        sessions = Sessions.list_sessions_with_details()

        socket =
          socket
          |> assign(:sessions, sessions)
          |> assign(:expanded_session_ids, expanded_ids)
          |> put_flash(:info, "Session deleted successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        socket =
          socket
          |> put_flash(:error, "Failed to delete session")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_edit_product_modal", %{"product-id" => product_id}, socket) do
    product = Catalog.get_product_with_images!(product_id)

    changeset = Product.changeset(product, %{})

    socket =
      socket
      |> assign(:editing_product, product)
      |> assign(:product_edit_form, to_form(changeset))

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_edit_product_modal", _params, socket) do
    socket =
      socket
      |> assign(:editing_product, nil)
      |> assign(:product_edit_form, to_form(Product.changeset(%Product{}, %{})))

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_product", %{"product" => product_params}, socket) do
    # Convert price fields from dollars to cents
    product_params = convert_prices_to_cents(product_params)

    case Catalog.update_product(socket.assigns.editing_product, product_params) do
      {:ok, _product} ->
        # Refresh the sessions list
        sessions = Sessions.list_sessions_with_details()
        expanded_ids = socket.assigns.expanded_session_ids

        socket =
          socket
          |> assign(:sessions, sessions)
          |> assign(:expanded_session_ids, expanded_ids)
          |> assign(:editing_product, nil)
          |> assign(:product_edit_form, to_form(Product.changeset(%Product{}, %{})))
          |> put_flash(:info, "Product updated successfully")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        socket =
          socket
          |> assign(:product_edit_form, to_form(changeset))
          |> put_flash(:error, "Please fix the errors below")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search_products", %{"value" => query}, socket) do
    socket =
      socket
      |> assign(:product_search_query, query)
      |> assign(:product_page, 1)
      |> load_products_for_new_session()

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more_products", _params, socket) do
    socket = load_products_for_new_session(socket, append: true)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_product_selection", %{"product-id" => product_id}, socket) do
    product_id = normalize_id(product_id)
    selected_ids = socket.assigns.selected_product_ids

    new_selected_ids =
      if MapSet.member?(selected_ids, product_id) do
        MapSet.delete(selected_ids, product_id)
      else
        MapSet.put(selected_ids, product_id)
      end

    {:noreply, assign(socket, :selected_product_ids, new_selected_ids)}
  end

  # Helper functions

  defp load_products_for_new_session(socket, opts \\ [append: false]) do
    append = Keyword.get(opts, :append, false)

    brand_id = get_in(socket.assigns.session_form.params, ["brand_id"])
    search_query = socket.assigns.product_search_query
    page = if append, do: socket.assigns.product_page + 1, else: 1

    case brand_id do
      nil ->
        socket
        |> assign(:new_session_products, [])
        |> assign(:new_session_has_more, false)
        |> assign(:product_total_count, 0)

      "" ->
        socket
        |> assign(:new_session_products, [])
        |> assign(:new_session_has_more, false)
        |> assign(:product_total_count, 0)

      brand_id_str ->
        brand_id = String.to_integer(brand_id_str)

        result =
          Catalog.search_products_paginated(
            brand_id: brand_id,
            search_query: search_query,
            page: page,
            per_page: 20
          )

        products =
          if append do
            socket.assigns.new_session_products ++ result.products
          else
            result.products
          end

        socket
        |> assign(:new_session_products, products)
        |> assign(:product_total_count, result.total)
        |> assign(:product_page, result.page)
        |> assign(:new_session_has_more, result.has_more)
    end
  end

  defp convert_prices_to_cents(params) do
    params
    |> convert_price_field("original_price_cents")
    |> convert_price_field("sale_price_cents")
  end

  defp convert_price_field(params, field) do
    case Map.get(params, field) do
      nil ->
        params

      "" ->
        Map.put(params, field, nil)

      value when is_binary(value) ->
        # If value contains decimal point, treat as dollars, otherwise as cents
        if String.contains?(value, ".") do
          case Float.parse(value) do
            {dollars, _} -> Map.put(params, field, round(dollars * 100))
            :error -> params
          end
        else
          params
        end

      value when is_integer(value) ->
        params

      _ ->
        params
    end
  end

  defp normalize_id(id) when is_integer(id), do: id
  defp normalize_id(id) when is_binary(id), do: String.to_integer(id)

  defp slugify(name) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^\w\s-]/, "")
      |> String.replace(~r/\s+/, "-")
      |> String.trim("-")

    # Fallback for empty slugs
    if slug == "", do: "session-#{:os.system_time(:second)}", else: slug
  end

  defp primary_image(product) do
    product.product_images
    |> Enum.find(& &1.is_primary)
    |> case do
      nil -> List.first(product.product_images)
      image -> image
    end
  end

  def public_image_url(path) do
    Hudson.Media.public_image_url(path)
  end
end
