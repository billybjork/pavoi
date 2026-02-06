defmodule PavoiWeb.UserLive.Settings do
  use PavoiWeb, :live_view

  on_mount {PavoiWeb.UserAuth, :require_sudo_mode}

  alias Pavoi.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      current_brand={@current_brand}
      current_page={@current_page}
      user_brands={@user_brands}
      current_host={@current_host}
    >
      <div class="container container--sm region">
        <div class="settings-page">
          <section class="settings-section">
            <div class="settings-section__header">
              <h2 class="settings-section__title">Email Address</h2>
              <p class="settings-section__description">
                Update your email address. A confirmation link will be sent to the new address.
              </p>
            </div>

            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
              class="stack"
            >
              <.input
                field={@email_form[:email]}
                type="email"
                label="Email"
                autocomplete="username"
                required
              />
              <div>
                <.button variant="primary" phx-disable-with="Changing...">
                  Change Email
                </.button>
              </div>
            </.form>
          </section>

          <section class="settings-section">
            <.button href={~p"/users/log-out"} method="delete" variant="outline">
              Log out
            </.button>
          </section>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)

    # Get user's brands for the navbar
    user_brands = Accounts.list_user_brands(user)
    # Use the first brand as the current brand for navbar context
    first_brand =
      case user_brands do
        [ub | _] -> ub.brand
        [] -> nil
      end

    socket =
      socket
      |> assign(:current_brand, first_brand)
      |> assign(:user_brands, user_brands)
      |> assign(:current_host, nil)
      |> assign(:current_page, :account_settings)
      |> assign(:email_form, to_form(email_changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end
end
