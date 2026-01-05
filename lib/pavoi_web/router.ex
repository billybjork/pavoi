defmodule PavoiWeb.Router do
  use PavoiWeb, :router

  # Custom CSP that allows GrapesJS template editor to function
  # The editor needs 'unsafe-inline' and 'unsafe-eval' for its canvas iframe
  # Also allows cdnjs.cloudflare.com for Font Awesome (used by newsletter plugin)
  @csp_header %{
    "content-security-policy" =>
      "default-src 'self'; " <>
        "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: data:; " <>
        "style-src 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; " <>
        "style-src-elem 'self' 'unsafe-inline' https://cdnjs.cloudflare.com; " <>
        "img-src 'self' data: blob: https:; " <>
        "font-src 'self' data: https://cdnjs.cloudflare.com; " <>
        "frame-src 'self' blob: data:; " <>
        "child-src 'self' blob: data:; " <>
        "connect-src 'self' ws: wss: https://storage.railway.app; " <>
        "frame-ancestors 'self'; " <>
        "base-uri 'self';"
  }

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PavoiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers, @csp_header
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check endpoint (no auth, no database)
  scope "/", PavoiWeb do
    get "/health", HealthController, :check
  end

  # Protected pipeline - requires password in production if SITE_PASSWORD env var is set
  pipeline :protected do
    plug PavoiWeb.Plugs.RequirePassword
  end

  # Authentication routes (not protected to avoid infinite redirect)
  scope "/auth", PavoiWeb do
    pipe_through :browser

    get "/login", AuthController, :login
    post "/authenticate", AuthController, :authenticate
    get "/logout", AuthController, :logout
  end

  # TikTok Shop OAuth routes (not protected to allow callbacks)
  scope "/tiktok", PavoiWeb do
    pipe_through :browser

    get "/callback", TiktokShopController, :callback
  end

  # TikTok Shop API test route
  scope "/api/tiktok", PavoiWeb do
    pipe_through :api

    get "/test", TiktokShopController, :test
  end

  # SendGrid webhook endpoint (unauthenticated - SendGrid POSTs here)
  scope "/webhooks", PavoiWeb do
    pipe_through :api

    post "/sendgrid", SendgridWebhookController, :handle
  end

  # Public pages (unauthenticated - accessed from email links)
  scope "/", PavoiWeb do
    pipe_through :browser

    get "/unsubscribe/:token", UnsubscribeController, :unsubscribe
    live "/join/:token", JoinLive, :index
  end

  # Main application routes (protected in production)
  scope "/", PavoiWeb do
    pipe_through [:browser, :protected]

    # Redirect root to readme/documentation page
    get "/", Redirector, :redirect_to_readme

    # Product Sets (merged sessions + products with tabs)
    live "/product-sets", ProductSetsLive.Index
    live "/product-sets/:id/host", ProductSetHostLive.Index
    live "/product-sets/:id/controller", ProductSetControllerLive.Index

    # Legacy redirects (for bookmarks)
    get "/sessions", Redirector, :redirect_to_product_sets
    get "/products", Redirector, :redirect_to_product_sets_products

    # Creator CRM (includes outreach mode via ?view=outreach)
    live "/creators", CreatorsLive.Index

    # Email template editor (full-page GrapesJS)
    live "/templates/new", TemplateEditorLive, :new
    live "/templates/:id/edit", TemplateEditorLive, :edit

    # TikTok Live stream data browser
    live "/streams", TiktokLive.Index

    # Documentation/directory page
    live "/readme", ReadmeLive.Index
  end

  # Other scopes may use custom stacks.
  # scope "/api", PavoiWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:pavoi, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: PavoiWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
