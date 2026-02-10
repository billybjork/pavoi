defmodule SocialObjectsWeb.AdminLive.Users do
  @moduledoc """
  Admin page for listing and managing all users.
  Includes user detail modal for viewing/editing individual users.
  """
  use SocialObjectsWeb, :live_view

  import SocialObjectsWeb.AdminComponents

  alias SocialObjects.Accounts
  alias SocialObjects.Catalog
  alias Phoenix.LiveView.JS

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_all_users()
    brands = Catalog.list_brands()

    # Fetch last session timestamps for all users
    users_with_sessions =
      Enum.map(users, fn user ->
        last_session = Accounts.get_last_session_at(user)
        Map.put(user, :last_session_at, last_session)
      end)

    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> assign(:users, users_with_sessions)
     |> assign(:brands, brands)
     |> assign(:selected_user, nil)
     |> assign(:selected_user_last_session, nil)
     |> assign(:show_new_user_modal, false)
     |> assign(:new_user_form, to_form(%{"email" => ""}))
     |> assign(:created_user_email, nil)
     |> assign(:created_user_temp_password, nil)}
  end

  @impl true
  def handle_event("view_user", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user_with_brands!(user_id)
    last_session = Accounts.get_last_session_at(user)

    {:noreply,
     socket
     |> assign(:selected_user, user)
     |> assign(:selected_user_last_session, last_session)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_user, nil)
     |> assign(:selected_user_last_session, nil)
     |> assign(:show_new_user_modal, false)
     |> assign(:created_user_email, nil)
     |> assign(:created_user_temp_password, nil)}
  end

  @impl true
  def handle_event("show_new_user_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_new_user_modal, true)
     |> assign(:new_user_form, to_form(%{"email" => ""}))}
  end

  @impl true
  def handle_event("create_user", params, socket) do
    email = String.trim(params["email"] || "")
    is_admin = params["is_admin"] == "true"
    brand_assignments = parse_brand_assignments(params["brands"] || %{})

    case Accounts.create_user_with_temp_password(email) do
      {:ok, user, temp_password} ->
        # Set admin status if requested
        if is_admin do
          Accounts.set_admin_status(user, true)
        end

        # Assign to selected brands
        for {brand_id, role} <- brand_assignments do
          brand = Catalog.get_brand!(brand_id)
          Accounts.create_user_brand(user, brand, role)
        end

        # Reload users list
        users = reload_users()

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign(:show_new_user_modal, false)
         |> assign(:new_user_form, to_form(%{"email" => ""}))
         |> assign(:created_user_email, email)
         |> assign(:created_user_temp_password, temp_password)}

      {:error, changeset} ->
        error_msg = format_changeset_errors(changeset)

        {:noreply, put_flash(socket, :error, "Failed to create user: #{error_msg}")}
    end
  end

  @impl true
  def handle_event("toggle_admin", %{"user_id" => user_id}, socket) do
    user = Accounts.get_user_with_brands!(user_id)
    new_status = !user.is_admin

    case Accounts.set_admin_status(user, new_status) do
      {:ok, updated_user} ->
        # Reload with brands
        updated_user = Accounts.get_user_with_brands!(updated_user.id)
        last_session = Accounts.get_last_session_at(updated_user)

        # Update users list
        users = update_user_in_list(socket.assigns.users, updated_user, last_session)

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign(:selected_user, updated_user)
         |> put_flash(:info, "Admin status updated.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update admin status.")}
    end
  end

  @impl true
  def handle_event("remove_from_brand", %{"user_id" => user_id, "brand_id" => brand_id}, socket) do
    user = Accounts.get_user_with_brands!(user_id)
    brand = Catalog.get_brand!(brand_id)

    case Accounts.remove_user_from_brand(user, brand) do
      {1, _} ->
        updated_user = Accounts.get_user_with_brands!(user.id)
        last_session = Accounts.get_last_session_at(updated_user)

        # Update users list
        users = update_user_in_list(socket.assigns.users, updated_user, last_session)

        {:noreply,
         socket
         |> assign(:users, users)
         |> assign(:selected_user, updated_user)
         |> put_flash(:info, "User removed from #{brand.name}.")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to remove user from brand.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="admin-page">
      <div class="admin-page__header">
        <h1 class="admin-page__title">Users</h1>
        <.button phx-click="show_new_user_modal" variant="primary">
          Add User
        </.button>
      </div>

      <div class="admin-panel">
        <div class="admin-panel__body--flush">
          <.admin_table id="users-table" rows={@users} row_id={fn user -> "user-#{user.id}" end}>
            <:col :let={user} label="Email">
              {user.email}
            </:col>
            <:col :let={user} label="Admin">
              <.badge :if={user.is_admin} variant={:primary}>Admin</.badge>
              <span :if={!user.is_admin} class="text-secondary">-</span>
            </:col>
            <:col :let={user} label="Brands">
              {format_user_brands(user.user_brands)}
            </:col>
            <:col :let={user} label="Last Session">
              {format_datetime(user.last_session_at)}
            </:col>
            <:col :let={user} label="Created">
              {format_datetime(user.inserted_at)}
            </:col>
            <:action :let={user}>
              <.button phx-click="view_user" phx-value-user_id={user.id} size="sm" variant="outline">
                View
              </.button>
            </:action>
          </.admin_table>
        </div>
      </div>

      <.user_detail_modal
        :if={@selected_user}
        user={@selected_user}
        last_session_at={@selected_user_last_session}
        on_cancel={JS.push("close_modal")}
      />

      <.new_user_modal
        :if={@show_new_user_modal}
        form={@new_user_form}
        brands={@brands}
        on_cancel={JS.push("close_modal")}
      />

      <.user_created_modal
        :if={@created_user_temp_password}
        email={@created_user_email}
        temp_password={@created_user_temp_password}
        on_close={JS.push("close_modal")}
      />
    </div>
    """
  end

  defp format_user_brands(user_brands) when is_list(user_brands) do
    Enum.map_join(user_brands, ", ", fn ub -> "#{ub.brand.name} (#{ub.role})" end)
  end

  defp format_user_brands(_), do: "-"

  defp format_datetime(nil), do: "-"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %H:%M")
  end

  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %H:%M")
  end

  defp reload_users do
    Accounts.list_all_users()
    |> Enum.map(fn user ->
      last_session = Accounts.get_last_session_at(user)
      Map.put(user, :last_session_at, last_session)
    end)
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} -> "#{field} #{Enum.join(errors, ", ")}" end)
  end

  defp update_user_in_list(users, updated_user, last_session) do
    Enum.map(users, fn user ->
      if user.id == updated_user.id do
        updated_user
        |> Map.put(:last_session_at, last_session)
      else
        user
      end
    end)
  end

  defp parse_brand_assignments(brands_params) when is_map(brands_params) do
    brands_params
    |> Enum.filter(fn {_brand_id, params} -> params["enabled"] == "true" end)
    |> Enum.map(fn {brand_id, params} ->
      role = String.to_existing_atom(params["role"] || "viewer")
      {brand_id, role}
    end)
  end

  defp parse_brand_assignments(_), do: []
end
