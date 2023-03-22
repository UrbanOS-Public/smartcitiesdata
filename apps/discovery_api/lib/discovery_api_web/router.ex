defmodule DiscoveryApiWeb.Router do
  @moduledoc """
  Module containing all of the app's routes and their respective controllers
  """
  use DiscoveryApiWeb, :router

  pipeline :verify_token do
    plug(Guardian.Plug.Pipeline,
      otp_app: :discovery_api,
      module: DiscoveryApiWeb.Auth.TokenHandler,
      error_handler: DiscoveryApiWeb.Auth.ErrorHandler
    )

    plug(Auth.Guardian.Plug.VerifyHeader)
  end

  pipeline :add_user_details do
    plug(Guardian.Plug.LoadResource, allow_blank: true)
    plug(DiscoveryApiWeb.Plugs.SetCurrentUser)
  end

  pipeline :ensure_authenticated do
    plug(Guardian.Plug.EnsureAuthenticated)
  end

  pipeline :ensure_user_details_loaded do
    plug(Guardian.Plug.LoadResource, allow_blank: false)
    plug(DiscoveryApiWeb.Plugs.SetCurrentUser)
  end

  pipeline :reject_cookies_from_ajax do
    plug(DiscoveryApiWeb.Plugs.SetAllowedOrigin)
  end

  pipeline :global_headers do
    plug(DiscoveryApiWeb.Plugs.NoStore)
  end

  pipeline :telemetry do
    plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]
  end

  scope "/api/v2", DiscoveryApiWeb do
    pipe_through([:reject_cookies_from_ajax, :verify_token, :add_user_details, :global_headers, :telemetry])
    get("/dataset/search", SearchController, :advanced_search)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:reject_cookies_from_ajax, :verify_token, :ensure_authenticated, :global_headers, :telemetry])

    post("/logged-in", UserController, :logged_in)
    post("/logged-out", UserController, :logged_out)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:reject_cookies_from_ajax, :verify_token, :add_user_details, :global_headers, :telemetry])

    get("/data_json", DataJsonController, :show)
    post("/query", MultipleDataController, :query)

    get("/tableau/table_info", TableauController, :fetch_table_info)
    post("/tableau/query_describe", TableauController, :describe)

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
    get("/dataset/:dataset_id/download/presigned_url", DataController, :download_presigned_url)

    patch("/regenerateApiKey", ApiKeyController, :regenerate_api_key)

    resources("/visualization", VisualizationController, only: [:show])
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:reject_cookies_from_ajax, :global_headers, :telemetry])
    get("/organization/:org_name/dataset/:dataset_name/download", DataDownloadController, :fetch_file)
    get("/dataset/:dataset_id/download", DataDownloadController, :fetch_file)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([
      :reject_cookies_from_ajax,
      :verify_token,
      :ensure_user_details_loaded,
      :ensure_authenticated,
      :global_headers,
      :telemetry
    ])

    resources("/visualization", VisualizationController, only: [:create, :update, :index, :delete])
  end
end
