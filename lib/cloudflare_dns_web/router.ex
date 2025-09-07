defmodule CloudflareDnsWeb.Router do
  use CloudflareDnsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CloudflareDnsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :auth do
    plug CloudflareDnsWeb.Auth, :require_auth
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Public routes (no auth required)
  scope "/", CloudflareDnsWeb do
    pipe_through :browser

    live "/login", LoginLive, :index
    post "/login", PageController, :login
    post "/logout", PageController, :logout
  end

  # Protected routes (require authentication)
  scope "/", CloudflareDnsWeb do
    pipe_through [:browser, :auth]

    live "/", DashboardLive, :index
    live "/records/new", RecordLive, :new
    live "/records/:id/edit", RecordLive, :edit
  end

  # Other scopes may use custom stacks.
  # scope "/api", CloudflareDnsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:cloudflare_dns, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CloudflareDnsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
