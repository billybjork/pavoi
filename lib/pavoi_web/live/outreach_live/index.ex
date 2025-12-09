defmodule PavoiWeb.OutreachLive.Index do
  @moduledoc """
  LiveView for the creator outreach management page.

  Displays pending creators for outreach review, allows bulk selection and sending,
  and shows outreach history and statistics.
  """
  use PavoiWeb, :live_view

  on_mount {PavoiWeb.NavHooks, :set_current_page}

  alias Pavoi.Outreach
  alias Pavoi.Settings
  alias Pavoi.Workers.CreatorOutreachWorker

  @impl true
  def mount(_params, _session, socket) do
    # Get the Lark invite URL from settings
    lark_invite_url = Settings.get_setting("lark_invite_url") || ""

    socket =
      socket
      |> assign(:creators, [])
      |> assign(:tab, "pending")
      |> assign(:search_query, "")
      |> assign(:page, 1)
      |> assign(:per_page, 50)
      |> assign(:total, 0)
      |> assign(:has_more, false)
      |> assign(:selected_ids, MapSet.new())
      |> assign(:stats, %{pending: 0, sent: 0, skipped: 0})
      |> assign(:sent_today, 0)
      |> assign(:lark_invite_url, lark_invite_url)
      |> assign(:show_send_modal, false)
      |> assign(:sending, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tab = Map.get(params, "tab", "pending")
    search_query = Map.get(params, "q", "")
    page = String.to_integer(Map.get(params, "page", "1"))

    socket =
      socket
      |> assign(:tab, tab)
      |> assign(:search_query, search_query)
      |> assign(:page, page)
      |> assign(:selected_ids, MapSet.new())
      |> load_creators()
      |> load_stats()

    {:noreply, socket}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/outreach?tab=#{tab}")}
  end

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    params = %{tab: socket.assigns.tab, q: query}
    {:noreply, push_patch(socket, to: ~p"/outreach?#{params}")}
  end

  @impl true
  def handle_event("toggle_selection", %{"id" => id}, socket) do
    id = String.to_integer(id)
    selected = socket.assigns.selected_ids

    selected =
      if MapSet.member?(selected, id) do
        MapSet.delete(selected, id)
      else
        MapSet.put(selected, id)
      end

    {:noreply, assign(socket, :selected_ids, selected)}
  end

  @impl true
  def handle_event("select_all", _params, socket) do
    all_ids = Enum.map(socket.assigns.creators, & &1.id) |> MapSet.new()
    {:noreply, assign(socket, :selected_ids, all_ids)}
  end

  @impl true
  def handle_event("deselect_all", _params, socket) do
    {:noreply, assign(socket, :selected_ids, MapSet.new())}
  end

  @impl true
  def handle_event("show_send_modal", _params, socket) do
    if MapSet.size(socket.assigns.selected_ids) > 0 do
      {:noreply, assign(socket, :show_send_modal, true)}
    else
      {:noreply, put_flash(socket, :error, "Please select at least one creator")}
    end
  end

  @impl true
  def handle_event("close_send_modal", _params, socket) do
    {:noreply, assign(socket, :show_send_modal, false)}
  end

  @impl true
  def handle_event("update_lark_url", %{"url" => url}, socket) do
    {:noreply, assign(socket, :lark_invite_url, url)}
  end

  @impl true
  def handle_event("send_outreach", _params, socket) do
    lark_url = String.trim(socket.assigns.lark_invite_url)

    if lark_url == "" do
      {:noreply, put_flash(socket, :error, "Please enter a Lark invite URL")}
    else
      # Save the Lark URL for future use
      Settings.set_setting("lark_invite_url", lark_url)

      # Get selected creator IDs
      creator_ids = MapSet.to_list(socket.assigns.selected_ids)

      # Enqueue outreach jobs
      {:ok, count} = CreatorOutreachWorker.enqueue_batch(creator_ids, lark_url)

      socket =
        socket
        |> assign(:show_send_modal, false)
        |> assign(:selected_ids, MapSet.new())
        |> put_flash(:info, "Queued #{count} outreach messages for sending")
        |> push_patch(to: ~p"/outreach?tab=sent")

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("skip_selected", _params, socket) do
    creator_ids = MapSet.to_list(socket.assigns.selected_ids)

    if length(creator_ids) > 0 do
      count = Outreach.mark_creators_skipped(creator_ids)

      socket =
        socket
        |> assign(:selected_ids, MapSet.new())
        |> put_flash(:info, "Skipped #{count} creators")
        |> load_creators()
        |> load_stats()

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Please select at least one creator")}
    end
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if socket.assigns.has_more do
      {:noreply, load_more_creators(socket)}
    else
      {:noreply, socket}
    end
  end

  # Private functions

  defp load_creators(socket) do
    status =
      case socket.assigns.tab do
        "sent" -> "sent"
        "skipped" -> "skipped"
        _ -> "pending"
      end

    result =
      Outreach.list_creators_by_status(status,
        page: socket.assigns.page,
        per_page: socket.assigns.per_page,
        search_query: socket.assigns.search_query
      )

    socket
    |> assign(:creators, result.creators)
    |> assign(:total, result.total)
    |> assign(:has_more, result.has_more)
  end

  defp load_more_creators(socket) do
    next_page = socket.assigns.page + 1

    status =
      case socket.assigns.tab do
        "sent" -> "sent"
        "skipped" -> "skipped"
        _ -> "pending"
      end

    result =
      Outreach.list_creators_by_status(status,
        page: next_page,
        per_page: socket.assigns.per_page,
        search_query: socket.assigns.search_query
      )

    socket
    |> assign(:page, next_page)
    |> assign(:creators, socket.assigns.creators ++ result.creators)
    |> assign(:has_more, result.has_more)
  end

  defp load_stats(socket) do
    stats = Outreach.get_outreach_stats()
    sent_today = Outreach.count_sent_today()

    socket
    |> assign(:stats, stats)
    |> assign(:sent_today, sent_today)
  end
end
