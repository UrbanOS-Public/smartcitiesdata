defmodule AndiWeb.Router do
  use AndiWeb, :router
  require Ueberauth

  @csp "default-src 'self';" <>
         "style-src 'self' 'unsafe-inline' 'unsafe-eval';" <>
         "script-src 'self' 'unsafe-inline' 'unsafe-eval';" <>
         "font-src https://fonts.gstatic.com data: 'self';" <>
         "img-src 'self' https: data:;"

  pipeline :browser do
    plug Plug.Logger
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers, %{"content-security-policy" => @csp}
    plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  end

  pipeline :auth do
    plug AndiWeb.Auth.Pipeline
  end

  pipeline :curator do
    plug Guardian.Plug.EnsureAuthenticated, claims: %{"https://andi.smartcolumbusos.com/roles" => ["Curator"]}
  end

  pipeline :api_curator do
    plug AndiWeb.Plugs.APIRequireCurator
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Logger
    plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  end

  scope "/", AndiWeb do
    pipe_through [:browser, :auth]

    get "/", Redirect, to: "/datasets"
    live "/datasets", DatasetLiveView, layout: {AndiWeb.LayoutView, :app}, session: {AndiWeb.Auth.TokenHandler.Plug, :current_resource, []}
    get "/submissions/:id", EditController, :edit_submission

    get "/auth/auth0/logout", AuthController, :logout
  end

  scope "/", AndiWeb do
    pipe_through [:browser, :auth, :curator]

    live "/organizations", OrganizationLiveView,
      layout: {AndiWeb.LayoutView, :app},
      session: {AndiWeb.Auth.TokenHandler.Plug, :current_resource, []}

    live "/users", UserLiveView,
      layout: {AndiWeb.LayoutView, :app},
      session: {AndiWeb.Auth.TokenHandler.Plug, :current_resource, []}

    live "/access-groups", AccessGroupLiveView,
      layout: {AndiWeb.LayoutView, :app},
      session: {AndiWeb.Auth.TokenHandler.Plug, :current_resource, []}

    live "/ingestions", IngestionLiveView,
      layout: {AndiWeb.LayoutView, :app},
      session: {AndiWeb.Auth.TokenHandler.Plug, :current_resource, []}

    live "/reports", ReportsLiveView,
      layout: {AndiWeb.LayoutView, :app},
      session: {AndiWeb.Auth.TokenHandler.Plug, :current_resource, []}

    get "/datasets/:id", EditController, :edit_dataset
    get "/access-groups/:id", EditController, :edit_access_group
    get "/ingestions/:id", EditController, :edit_ingestion
    get "/organizations/:id", EditController, :edit_organization
    get "/datasets/:id/sample", EditController, :download_dataset_sample
    get "/user/:id", EditController, :edit_user
    get "/report", ReportsController, :download_report
  end

  scope "/api", AndiWeb.API do
    pipe_through [:api, :api_curator]

    get "/v1/datasets", DatasetController, :get_all
    get "/v1/dataset/:dataset_id", DatasetController, :get
    get "/v1/ingestions", IngestionController, :get_all
    get "/v1/ingestion/:ingestion_id", IngestionController, :get
    put "/v1/dataset", DatasetController, :create
    put "/v1/ingestion", IngestionController, :create
    post "/v1/ingestion/publish", IngestionController, :publish
    post "/v1/dataset/disable", DatasetController, :disable
    post "/v1/dataset/delete", DatasetController, :delete
    post "/v1/ingestion/delete", IngestionController, :delete
    get "/v1/organizations", OrganizationController, :get_all
    post "/v1/organization/:org_id/users/add", OrganizationController, :add_users_to_organization
    post "/v1/organization", OrganizationController, :create
  end

  scope "/auth", AndiWeb do
    pipe_through :browser

    get "/auth0", AuthController, :request
    get "/auth0/callback", AuthController, :callback
  end

  scope "/", AndiWeb do
    get "/healthcheck", HealthCheckController, :index
  end
end
