defmodule PavoiWeb.UserLive.Confirmation do
  use PavoiWeb, :live_view

  alias Pavoi.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <div class="auth-page">
      <Layouts.flash_group flash={@flash} />

      <div class="auth-card">
        <div class="auth-card__logo">
          <img
            src={~p"/images/logo-light.svg"}
            class="auth-card__logo--light"
            alt="Logo"
          />
          <img
            src={~p"/images/logo-dark.svg"}
            class="auth-card__logo--dark"
            alt="Logo"
          />
        </div>

        <div class="auth-header">
          <h1 class="auth-title">Welcome back</h1>
          <p class="auth-subtitle">
            Signing in as <strong>{@user.email}</strong>
          </p>
        </div>

        <.form
          for={@form}
          id="confirmation_form"
          phx-mounted={JS.focus_first()}
          phx-submit="submit"
          action={
            if @user.confirmed_at, do: ~p"/users/log-in", else: ~p"/users/log-in?_action=confirmed"
          }
          phx-trigger-action={@trigger_submit}
          class="auth-form"
        >
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <input type="hidden" name={@form[:remember_me].name} value="true" />
          <.button variant="primary" phx-disable-with="Signing in...">
            Continue to dashboard <span aria-hidden="true">→</span>
          </.button>
        </.form>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if user = Accounts.get_user_by_magic_link_token(token) do
      form = to_form(%{"token" => token}, as: "user")

      {:ok, assign(socket, user: user, form: form, trigger_submit: false),
       temporary_assigns: [form: nil]}
    else
      {:ok,
       socket
       |> put_flash(:error, "Magic link is invalid or it has expired.")
       |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
