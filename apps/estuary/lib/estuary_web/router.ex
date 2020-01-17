defmodule EstuaryWeb.Router do
  use EstuaryWeb, :router

  @csp "default-src 'self';" <>
         "style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com;" <>
         "script-src 'self' 'unsafe-inline' 'unsafe-eval';" <>
         "font-src https://fonts.gstatic.com data: 'self';" <>
         "img-src 'self' data:;"

  pipeline :browser do
    plug Plug.Logger
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug Phoenix.LiveView.Flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => @csp}
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Logger
  end

  scope "/", EstuaryWeb do
    pipe_through :browser

    get "/", Redirect, to: "/events"
    # live "/events", DatasetLiveView, session: [:path_params]
    # get "/events/:id", EditController, :show
  end

  scope "/api", EstuaryWeb.API do
    pipe_through :api

    get "/v1/events", EventController, :get_all
    # get "/v1/dataset/:dataset_id", DatasetController, :get
    # put "/v1/dataset", DatasetController, :create
    # post "/v1/dataset/disable", DatasetController, :disable
    # post "/v1/dataset/delete", DatasetController, :delete
    # get "/v1/organizations", OrganizationController, :get_all
    # post "/v1/organization/:org_id/users/add", OrganizationController, :add_users_to_organization
    # post "/v1/organization", OrganizationController, :create
    # post "/v1/repost_org_updates", OrganizationController, :repost_org_updates
  end

  scope "/", EstuaryWeb do
    get("/healthcheck", HealthCheckController, :index)
  end
end
