defmodule DiscoveryApiWeb.Router do
  use DiscoveryApiWeb, :router

  pipeline :api do
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
    get("/datasets", DiscoveryController, :fetch_dataset_summaries)
    get("/dataset/:dataset_id", DiscoveryController, :fetch_dataset_detail)
  end
end
