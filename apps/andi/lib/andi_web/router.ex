defmodule AndiWeb.Router do
  use AndiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Logger
  end

  scope "/api", AndiWeb do
    pipe_through :api

    get "/v1/dataset", DatasetController, :get_all
    put "/v1/dataset", DatasetController, :create
    get "/v1/organization", OrganizationController, :get_all
    post "/v1/organization", OrganizationController, :create
  end

  scope "/", AndiWeb do
    get("/healthcheck", HealthCheckController, :index)
  end
end
