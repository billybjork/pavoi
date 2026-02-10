defmodule SocialObjectsWeb.BrandAuth do
  use SocialObjectsWeb, :verified_routes

  @moduledoc """
  LiveView authentication helpers for resolving and authorizing brands.
  """

  alias SocialObjects.Accounts
  alias SocialObjects.Accounts.Scope
  alias SocialObjects.Catalog
  alias SocialObjects.Catalog.Brand

  @brand_scoped_views MapSet.new([
                        SocialObjectsWeb.ProductsLive.Index,
                        SocialObjectsWeb.ProductHostLive.Index,
                        SocialObjectsWeb.ProductControllerLive.Index,
                        SocialObjectsWeb.CreatorsLive.Index,
                        SocialObjectsWeb.VideosLive.Index,
                        SocialObjectsWeb.TemplateEditorLive,
                        SocialObjectsWeb.TiktokLive.Index,
                        SocialObjectsWeb.ShopAnalyticsLive.Index,
                        SocialObjectsWeb.ReadmeLive.Index
                      ])

  @doc """
  Resolves the brand from params or host and assigns it to the socket.
  """
  def on_mount(:set_brand, params, _session, socket) do
    if brand_scoped_view?(socket.view) do
      host = current_host(socket)

      brand =
        cond do
          is_binary(params["brand_slug"]) ->
            Catalog.get_brand_by_slug!(params["brand_slug"])

          is_binary(host) ->
            Catalog.get_brand_by_domain(host) || fallback_brand_for_host(host)

          true ->
            nil
        end

      case brand do
        %Brand{} = brand ->
          socket =
            socket
            |> Phoenix.Component.assign(:current_brand, brand)
            |> Phoenix.Component.assign(:current_host, host)
            |> maybe_assign_scope_brand(brand)

          {:cont, socket}

        nil ->
          socket =
            socket
            |> Phoenix.LiveView.put_flash(:error, "Brand not found.")
            |> Phoenix.LiveView.redirect(to: ~p"/")

          {:halt, socket}
      end
    else
      {:cont, socket}
    end
  end

  # Ensures the current user has access to the resolved brand and assigns their role.
  # Note: user_brands is loaded directly in the app layout, not here,
  # because on_mount assigns don't flow to layouts properly.
  def on_mount(:require_brand_access, _params, _session, socket) do
    if brand_scoped_view?(socket.view) do
      check_brand_access(socket)
    else
      {:cont, socket}
    end
  end

  defp check_brand_access(socket) do
    with user when not is_nil(user) <- extract_user(socket),
         brand when not is_nil(brand) <- socket.assigns[:current_brand],
         role when not is_nil(role) <- Accounts.get_user_brand_role(user, brand) do
      scope = Scope.with_brand(socket.assigns.current_scope, brand, role)

      socket =
        socket
        |> Phoenix.Component.assign(:current_scope, scope)
        |> Phoenix.Component.assign(:current_brand_role, role)

      {:cont, socket}
    else
      _ -> halt_with_no_access(socket)
    end
  end

  defp extract_user(socket) do
    case socket.assigns[:current_scope] do
      %Scope{user: user} -> user
      _ -> nil
    end
  end

  defp halt_with_no_access(socket) do
    socket =
      socket
      |> Phoenix.LiveView.put_flash(:error, "You don't have access to this brand.")
      |> Phoenix.LiveView.redirect(to: ~p"/")

    {:halt, socket}
  end

  defp maybe_assign_scope_brand(socket, brand) do
    case socket.assigns[:current_scope] do
      %Scope{} = scope ->
        # Role is assigned later in :require_brand_access
        Phoenix.Component.assign(socket, :current_scope, Scope.with_brand(scope, brand, nil))

      _ ->
        socket
    end
  end

  defp current_host(socket) do
    case socket.host_uri do
      %URI{host: host} when is_binary(host) -> host
      _ -> nil
    end
  end

  defp fallback_brand_for_host(host) when is_binary(host) do
    default_slug = Application.get_env(:social_objects, :default_brand_slug)
    host = String.downcase(host)

    if default_slug && host in ["localhost", "127.0.0.1"] do
      Catalog.get_brand_by_slug(default_slug)
    end
  end

  defp brand_scoped_view?(view) when is_atom(view) do
    MapSet.member?(@brand_scoped_views, view)
  end

  defp brand_scoped_view?(_view), do: false
end
