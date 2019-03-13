defmodule AndiWeb.Router do
  use AndiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Logger
  end

  scope "/api", AndiWeb do
    pipe_through :api

    put "/v1/dataset", DatasetController, :create
    post "/v1/organization", OrganizationController, :create
  end

  scope "/", AndiWeb do
    get("/healthcheck", HealthCheckController, :index)
  end
end
