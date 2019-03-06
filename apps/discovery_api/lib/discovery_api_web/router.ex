defmodule DiscoveryApiWeb.Router do
  use DiscoveryApiWeb, :router

  pipeline :api do
    plug(Plug.Logger)
    plug(:accepts, ["json", "csv"])
  end

  pipeline :api_csv_only do
    plug(Plug.Logger)
    plug(:accepts, ["csv"])
  end

  pipeline :api_json_only do
    plug(Plug.Logger)
    plug(:accepts, ["json"])
  end

  scope "/", DiscoveryApiWeb do
    get("/healthcheck", HealthCheckController, :index)
  end

  scope "/v1/api", DiscoveryApiWeb do
    pipe_through(:api_json_only)

    get("/dataset/:dataset_id/preview", DatasetPreviewController, :fetch_preview)
    get("/dataset/search", DatasetSearchController, :search)
    get("/dataset/:dataset_id", DatasetDetailController, :fetch_dataset_detail)
  end

  scope "/v1/api", DiscoveryApiWeb do
    pipe_through(:api)

    get("/dataset/:dataset_id/csv", DatasetQueryController, :fetch_presto)
  end
end
