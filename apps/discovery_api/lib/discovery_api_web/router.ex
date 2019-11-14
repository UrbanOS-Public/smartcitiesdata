defmodule DiscoveryApiWeb.Router do
  @moduledoc """
  Module containing all of the app's routes and their respective controllers
  """
  use DiscoveryApiWeb, :router

  pipeline :add_user_details do
    plug(Guardian.Plug.Pipeline,
      otp_app: :discovery_api,
      module: DiscoveryApi.Auth.Guardian,
      error_handler: DiscoveryApi.Auth.ErrorHandler
    )

    plug(Guardian.Plug.VerifyHeader, claims: %{iss: "discovery_api"}, realm: "Bearer")
    plug(Guardian.Plug.VerifyCookie)
    plug(Guardian.Plug.LoadResource, allow_blank: true)
    plug(DiscoveryApiWeb.Plugs.SetCurrentUser)
    plug(DiscoveryApiWeb.Plugs.SetAllowedOrigin)
  end

  pipeline :reject_cookies_from_ajax do
    plug(DiscoveryApiWeb.Plugs.SetAllowedOrigin)
    plug(DiscoveryApiWeb.Plugs.CookieMonster)
  end

  pipeline :global_headers do
    plug(DiscoveryApiWeb.Plugs.NoStore)
  end

  pipeline :add_user_auth0 do
    plug(Guardian.Plug.Pipeline,
      otp_app: :discovery_api,
      module: DiscoveryApi.Auth.Auth0.Guardian,
      error_handler: DiscoveryApi.Auth.Auth0.ErrorHandler
    )

    plug(DiscoveryApiWeb.Plugs.VerifyHeader)
    plug(DiscoveryApiWeb.Plugs.SetCurrentUser)
  end

  pipeline :ensure_user_auth0 do
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  scope "/", DiscoveryApiWeb do
    get("/healthcheck", HealthCheckController, :index)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:reject_cookies_from_ajax, :add_user_details, :global_headers])

    get("/login", LoginController, :login)
    get("/logout", LoginController, :logout)

    get("/dataset/search", MultipleMetadataController, :search)
    get("/data_json", MultipleMetadataController, :fetch_data_json)
    post("/query", MultipleDataController, :query)

    get("/organization/:id", OrganizationController, :fetch_detail)

    get("/organization/:org_name/dataset/:dataset_name", MetadataController, :fetch_detail)
    get("/dataset/:dataset_id", MetadataController, :fetch_detail)
    get("/dataset/:dataset_id/stats", MetadataController, :fetch_stats)
    get("/dataset/:dataset_id/metrics", MetadataController, :fetch_metrics)
    get("/dataset/:dataset_id/dictionary", MetadataController, :fetch_schema)

    get("/dataset/:dataset_id/recommendations", RecommendationController, :recommendations)

    get("/organization/:org_name/dataset/:dataset_name/preview", DataController, :fetch_preview)
    get("/dataset/:dataset_id/preview", DataController, :fetch_preview)
    get("/organization/:org_name/dataset/:dataset_name/query", DataController, :query)
    get("/dataset/:dataset_id/query", DataController, :query)
    get("/organization/:org_name/dataset/:dataset_name/download", DataController, :fetch_file)
    get("/dataset/:dataset_id/download", DataController, :fetch_file)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:add_user_auth0, :ensure_user_auth0])

    post("/logged-in", UserController, :logged_in)
    resources("/visualization", VisualizationController, only: [:create, :update])
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:add_user_auth0])

    resources("/visualization", VisualizationController, only: [:show])
  end
end
