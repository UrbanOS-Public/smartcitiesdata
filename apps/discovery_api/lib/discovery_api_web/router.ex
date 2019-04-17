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
    plug(DiscoveryApiWeb.Plugs.GetDataset)
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
    get("/organization/:org_name/dataset/:dataset_name", DatasetDetailController, :fetch_dataset_detail)
    get("/dataset/:dataset_id", DatasetDetailController, :fetch_dataset_detail)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api, :add_auth_details])
    get("/logout", LoginController, :logout)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api, :check_restricted])

    get("/organization/:org_name/dataset/:dataset_name/query", DatasetQueryController, :query)
    get("/dataset/:dataset_id/query", DatasetQueryController, :query)

    get("/organization/:org_name/dataset/:dataset_name/download", DatasetDownloadController, :fetch_presto)
    get("/dataset/:dataset_id/download", DatasetDownloadController, :fetch_presto)
    get("/logout", LoginController, :logout)
  end

  scope "/api/v1", DiscoveryApiWeb do
    pipe_through([:api])
    get("/login", LoginController, :new)
  end
end
