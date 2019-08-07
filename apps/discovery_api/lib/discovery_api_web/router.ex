defmodule DiscoveryApiWeb.Router do
  @moduledoc """
  Module containing all of the app's routes and their respective controllers
  """
  use DiscoveryApiWeb, :router

  pipeline :api do
    plug(Plug.Logger)
    plug(:accepts, ["csv", "json", "geojson"])
  end

  pipeline :api_csv_only do
    plug(Plug.Logger)
    plug(:accepts, ["csv"])
  end

  pipeline :api_json_only do
    plug(Plug.Logger)
    plug(:accepts, ["json"])
  end

  pipeline :api_geojson_only do
    plug(Plug.Logger)
    plug(:accepts, ["geojson"])
  end

  pipeline :api_any do
    plug(Plug.Logger)
    plug(DiscoveryApiWeb.Plugs.Acceptor)
  end

  pipeline :check_restricted do
    plug(DiscoveryApiWeb.Plugs.GetModel)
    plug(DiscoveryApi.Auth.Pipeline)
    plug(DiscoveryApiWeb.Plugs.Restrictor)
  end

  pipeline :add_auth_details do
    plug(DiscoveryApi.Auth.Pipeline)
  end

  scope "/", DiscoveryApiWeb do
    get("/healthcheck", HealthCheckController, :index)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api_json_only, :add_auth_details])

    get("/dataset/search", DatasetSearchController, :search)
    get("/data_json", DataJsonController, :get_data_json)
    get("/organization/:id", OrganizationController, :fetch_organization)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api_json_only, :check_restricted])

    get("/dataset/:dataset_id/preview", DatasetPreviewController, :fetch_preview)
    get("/dataset/:dataset_id/stats", DatasetStatsController, :fetch_dataset_stats)
    get("/organization/:org_name/dataset/:dataset_name", DatasetDetailController, :fetch_dataset_detail)
    get("/dataset/:dataset_id", DatasetDetailController, :fetch_dataset_detail)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api_geojson_only, :check_restricted])

    get("/dataset/:dataset_id/features_preview", DatasetPreviewController, :fetch_geojson_features)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api, :add_auth_details])
    get("/logout", LoginController, :logout)
    post("/query", DatasetQueryController, :query_multiple)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api, :check_restricted])

    get("/organization/:org_name/dataset/:dataset_name/query", DatasetQueryController, :query)
    get("/dataset/:dataset_id/query", DatasetQueryController, :query)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api_any, :check_restricted])
    get("/organization/:org_name/dataset/:dataset_name/download", DatasetDownloadController, :fetch_file)
    get("/dataset/:dataset_id/download", DatasetDownloadController, :fetch_file)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api])
    get("/login", LoginController, :new)
    get("/dataset/:dataset_id/metrics", DatasetMetricsController, :get)
  end
end
