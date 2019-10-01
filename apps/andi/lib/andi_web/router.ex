defmodule AndiWeb.Router do
  use AndiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Logger
  end

  scope "/api", AndiWeb do
    pipe_through :api

    get "/v1/datasets", DatasetController, :get_all
    get "/v1/dataset/:dataset_id", DatasetController, :get
    put "/v1/dataset", DatasetController, :create
    post "/v1/dataset/disable", DatasetController, :disable
    get "/v1/organizations", OrganizationController, :get_all
    post "/v1/organization", OrganizationController, :create
  end

  scope "/", AndiWeb do
    get("/healthcheck", HealthCheckController, :index)
  end
end
