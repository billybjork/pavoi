defmodule PavoiWeb.CreatorsLive.Index do
  @moduledoc """
  LiveView for the creator CRM list view.

  Displays a paginated, searchable, filterable table of creators.
  Modal overlay for creator details with tabbed interface.
  """
  use PavoiWeb, :live_view

  on_mount {PavoiWeb.NavHooks, :set_current_page}

  alias Pavoi.Creators
  alias Pavoi.Creators.Creator

  import PavoiWeb.CreatorComponents

  @impl true
  def mount(_params, _session, socket) do
    brands = Creators.list_brands_with_creators()

    socket =
      socket
      |> assign(:creators, [])
      |> assign(:search_query, "")
      |> assign(:badge_filter, "")
      |> assign(:brand_filter, "")
      |> assign(:sort_by, nil)
      |> assign(:sort_dir, "asc")
      |> assign(:page, 1)
      |> assign(:per_page, 50)
      |> assign(:total, 0)
      |> assign(:has_more, false)
      |> assign(:brands, brands)
      # Modal state
      |> assign(:selected_creator, nil)
      |> assign(:active_tab, "contact")
      |> assign(:editing_contact, false)
      |> assign(:contact_form, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> apply_params(params)
      |> load_creators()
      |> maybe_load_selected_creator(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    params = build_query_params(socket, search_query: query, page: 1)
    {:noreply, push_patch(socket, to: ~p"/creators?#{params}")}
  end

  @impl true
  def handle_event("filter_badge", %{"badge" => badge}, socket) do
    params = build_query_params(socket, badge_filter: badge, page: 1)
    {:noreply, push_patch(socket, to: ~p"/creators?#{params}")}
  end

  @impl true
  def handle_event("filter_brand", %{"brand" => brand}, socket) do
    params = build_query_params(socket, brand_filter: brand, page: 1)
    {:noreply, push_patch(socket, to: ~p"/creators?#{params}")}
  end

  @impl true
  def handle_event("sort_column", %{"field" => field, "dir" => dir}, socket) do
    params = build_query_params(socket, sort_by: field, sort_dir: dir, page: 1)
    {:noreply, push_patch(socket, to: ~p"/creators?#{params}")}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    params = build_query_params(socket, page: socket.assigns.page + 1)
    {:noreply, push_patch(socket, to: ~p"/creators?#{params}")}
  end

  @impl true
  def handle_event("navigate_to_creator", %{"id" => id}, socket) do
    params = build_query_params(socket, creator_id: id)
    {:noreply, push_patch(socket, to: ~p"/creators?#{params}")}
  end

  @impl true
  def handle_event("close_creator_modal", _params, socket) do
    params = build_query_params(socket, creator_id: nil, tab: nil)

    socket =
      socket
      |> assign(:selected_creator, nil)
      |> assign(:active_tab, "contact")
      |> assign(:editing_contact, false)
      |> assign(:contact_form, nil)
      |> push_patch(to: ~p"/creators?#{params}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    params = build_query_params(socket, tab: tab)
    {:noreply, push_patch(socket, to: ~p"/creators?#{params}")}
  end

  @impl true
  def handle_event("edit_contact", _params, socket) do
    form =
      socket.assigns.selected_creator
      |> Creator.changeset(%{})
      |> to_form()

    socket =
      socket
      |> assign(:editing_contact, true)
      |> assign(:contact_form, form)

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    socket =
      socket
      |> assign(:editing_contact, false)
      |> assign(:contact_form, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_contact", %{"creator" => params}, socket) do
    changeset =
      socket.assigns.selected_creator
      |> Creator.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :contact_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_contact", %{"creator" => params}, socket) do
    case Creators.update_creator(socket.assigns.selected_creator, params) do
      {:ok, creator} ->
        # Reload with associations
        creator = Creators.get_creator_with_details!(creator.id)

        socket =
          socket
          |> assign(:selected_creator, creator)
          |> assign(:editing_contact, false)
          |> assign(:contact_form, nil)
          |> put_flash(:info, "Contact info updated")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :contact_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("stop_propagation", _params, socket) do
    {:noreply, socket}
  end

  defp apply_params(socket, params) do
    socket
    |> assign(:search_query, params["q"] || "")
    |> assign(:badge_filter, params["badge"] || "")
    |> assign(:brand_filter, params["brand"] || "")
    |> assign(:sort_by, params["sort"])
    |> assign(:sort_dir, params["dir"] || "asc")
    |> assign(:page, parse_page(params["page"]))
  end

  defp parse_page(nil), do: 1
  defp parse_page(page) when is_binary(page), do: String.to_integer(page)
  defp parse_page(page) when is_integer(page), do: page

  defp load_creators(socket) do
    %{
      search_query: search_query,
      badge_filter: badge_filter,
      brand_filter: brand_filter,
      sort_by: sort_by,
      sort_dir: sort_dir,
      page: page,
      per_page: per_page
    } = socket.assigns

    opts =
      [page: page, per_page: per_page]
      |> maybe_add_opt(:search_query, search_query)
      |> maybe_add_opt(:badge_level, badge_filter)
      |> maybe_add_opt(:brand_id, parse_brand_id(brand_filter))
      |> maybe_add_opt(:sort_by, sort_by)
      |> maybe_add_opt(:sort_dir, sort_dir)

    result = Creators.search_creators_paginated(opts)

    # Add sample counts to each creator
    creators_with_counts =
      Enum.map(result.creators, fn creator ->
        sample_count = Creators.count_samples_for_creator(creator.id)
        Map.put(creator, :sample_count, sample_count)
      end)

    # If loading more (page > 1), append to existing
    creators =
      if page > 1 do
        socket.assigns.creators ++ creators_with_counts
      else
        creators_with_counts
      end

    socket
    |> assign(:creators, creators)
    |> assign(:total, result.total)
    |> assign(:has_more, result.has_more)
  end

  defp maybe_add_opt(opts, _key, nil), do: opts
  defp maybe_add_opt(opts, _key, ""), do: opts
  defp maybe_add_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp parse_brand_id(""), do: nil
  defp parse_brand_id(nil), do: nil
  defp parse_brand_id(id) when is_binary(id), do: String.to_integer(id)
  defp parse_brand_id(id), do: id

  @override_key_mapping %{
    search_query: :q,
    badge_filter: :badge,
    brand_filter: :brand,
    sort_by: :sort,
    sort_dir: :dir,
    page: :page,
    creator_id: :c,
    tab: :tab
  }

  defp build_query_params(socket, overrides) do
    base = %{
      q: socket.assigns.search_query,
      badge: socket.assigns.badge_filter,
      brand: socket.assigns.brand_filter,
      sort: socket.assigns.sort_by,
      dir: socket.assigns.sort_dir,
      page: socket.assigns.page,
      c: get_creator_id(socket.assigns.selected_creator),
      tab: socket.assigns.active_tab
    }

    overrides
    |> Enum.reduce(base, fn {key, value}, acc ->
      Map.put(acc, Map.fetch!(@override_key_mapping, key), value)
    end)
    |> reject_default_values()
  end

  defp get_creator_id(nil), do: nil
  defp get_creator_id(creator), do: creator.id

  defp reject_default_values(params) do
    params
    |> Enum.reject(&default_value?/1)
    |> Map.new()
  end

  defp default_value?({_k, ""}), do: true
  defp default_value?({_k, nil}), do: true
  defp default_value?({:page, 1}), do: true
  defp default_value?({:dir, "asc"}), do: true
  defp default_value?({:tab, "contact"}), do: true
  defp default_value?(_), do: false

  defp maybe_load_selected_creator(socket, params) do
    case params["c"] do
      nil ->
        socket
        |> assign(:selected_creator, nil)
        |> assign(:active_tab, "contact")
        |> assign(:editing_contact, false)
        |> assign(:contact_form, nil)

      creator_id ->
        creator = Creators.get_creator_with_details!(creator_id)
        tab = params["tab"] || "contact"

        socket
        |> assign(:selected_creator, creator)
        |> assign(:active_tab, tab)
    end
  end
end
