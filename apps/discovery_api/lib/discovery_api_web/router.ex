defmodule DiscoveryApiWeb.Router do
  use DiscoveryApiWeb, :router

  pipeline :api do
    plug(:accepts, ["json", "csv"])
  end

  pipeline :api_csv_only do
    plug(:accepts, ["csv"])
  end

  pipeline :api_json_only do
    plug(:accepts, ["json"])
  end

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  scope "/", DiscoveryApiWeb do
    # Use the default browser stack
    pipe_through(:browser)
    get("/healthcheck", HealthCheckController, :index)
  end

  scope "/v1/api", DiscoveryApiWeb do
    pipe_through(:api)

    get("/dataset/:dataset_id/query", DatasetQueryController, :fetch_query)
    post("/dataset/:dataset_id/query", DatasetQueryController, :fetch_query)
    get("/dataset/:dataset/queryPresto", DatasetQueryController, :fetch_presto)
  end

  scope "/v1/api", DiscoveryApiWeb do
    pipe_through(:api_json_only)

    get("/dataset/:dataset_id/preview", DatasetQueryController, :fetch_preview)
    get("/dataset/search", DatasetSearchController, :search)
    get("/dataset/:dataset_id", DatasetDetailController, :fetch_dataset_detail)
  end

  scope "/v1/api", DiscoveryApiWeb do
    pipe_through(:api_csv_only)

    get("/dataset/:dataset_id/csv", DatasetQueryController, :fetch_full_csv)
  end
end
