defmodule DiscoveryApiWeb.Router do
  @moduledoc false
  use DiscoveryApiWeb, :router

  pipeline :api do
    plug(Plug.Logger)
    plug(:accepts, ["csv", "json"])
  end

  pipeline :api_csv_only do
    plug(Plug.Logger)
    plug(:accepts, ["csv"])
  end

  pipeline :api_json_only do
    plug(Plug.Logger)
    plug(:accepts, ["json"])
  end

  pipeline :check_restricted do
    plug(DiscoveryApi.Plugs.GetDataset)
    plug(DiscoveryApi.Auth.Pipeline)
    plug(DiscoveryApi.Plugs.Restrictor)
  end

  scope "/", DiscoveryApiWeb do
    get("/healthcheck", HealthCheckController, :index)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through(:api_json_only)

    get("/dataset/search", DatasetSearchController, :search)
    get("/data_json", DataJsonController, :get_data_json)
    get("/organization/:id", OrganizationController, :fetch_organization)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api_json_only, :check_restricted])

    get("/dataset/:dataset_id/preview", DatasetPreviewController, :fetch_preview)
    get("/dataset/:dataset_id", DatasetDetailController, :fetch_dataset_detail)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api, :check_restricted])

    get("/dataset/:dataset_id/query", DatasetQueryController, :query)
    get("/dataset/:dataset_id/download", DatasetDownloadController, :fetch_presto)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api])
    get("/login", LoginController, :new)
  end
end
