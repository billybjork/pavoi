defmodule SocialObjectsWeb.NavHooks do
  @moduledoc """
  LiveView lifecycle hooks for navigation state.
  """

  import Phoenix.LiveView

  def on_mount(:set_current_page, _params, _session, socket) do
    # Get the view module from the socket's private data
    view_module = socket.private[:phoenix_live_view][:view] || socket.view
    current_page = get_current_page(view_module)

    # Load user_brands once here instead of on every render in layout
    user_brands =
      case socket.assigns[:current_scope] do
        %{user: user} when not is_nil(user) ->
          SocialObjects.Accounts.list_user_brands(user)

        _ ->
          []
      end

    # Load feature flags and subscribe to changes
    feature_flags = SocialObjects.FeatureFlags.list_all()

    socket =
      socket
      |> Phoenix.Component.assign(:current_page, current_page)
      |> Phoenix.Component.assign(:user_brands, user_brands)
      |> Phoenix.Component.assign(:feature_flags, feature_flags)

    # Only attach the hook and subscribe when connected and not already attached
    socket =
      if Phoenix.LiveView.connected?(socket) and not hook_attached?(socket) do
        SocialObjects.FeatureFlags.subscribe()
        attach_hook(socket, :feature_flags_update, :handle_info, &handle_feature_flags_info/2)
      else
        socket
      end

    {:cont, socket}
  end

  defp hook_attached?(socket) do
    socket.private
    |> Map.get(:lifecycle, %{})
    |> Map.get(:handle_info, [])
    |> Enum.any?(fn {id, _} -> id == :feature_flags_update end)
  end

  defp handle_feature_flags_info(:feature_flags_changed, socket) do
    {:halt,
     Phoenix.Component.assign(socket, :feature_flags, SocialObjects.FeatureFlags.list_all())}
  end

  defp handle_feature_flags_info(_msg, socket), do: {:cont, socket}

  # Brand pages
  defp get_current_page(SocialObjectsWeb.ProductsLive.Index), do: :products
  defp get_current_page(SocialObjectsWeb.CreatorsLive.Index), do: :creators
  defp get_current_page(SocialObjectsWeb.VideosLive.Index), do: :videos
  defp get_current_page(SocialObjectsWeb.TiktokLive.Index), do: :streams
  defp get_current_page(SocialObjectsWeb.ShopAnalyticsLive.Index), do: :shop_analytics
  defp get_current_page(SocialObjectsWeb.ReadmeLive.Index), do: :readme

  # Admin pages - return :admin so nav shows but no tab is highlighted
  defp get_current_page(SocialObjectsWeb.AdminLive.Dashboard), do: :admin
  defp get_current_page(SocialObjectsWeb.AdminLive.Brands), do: :admin
  defp get_current_page(SocialObjectsWeb.AdminLive.Users), do: :admin

  # Full-page views return nil so navbar doesn't show
  defp get_current_page(SocialObjectsWeb.ProductHostLive.Index), do: nil
  defp get_current_page(SocialObjectsWeb.ProductControllerLive.Index), do: nil
  defp get_current_page(SocialObjectsWeb.TemplateEditorLive), do: nil
  defp get_current_page(_), do: nil
end
