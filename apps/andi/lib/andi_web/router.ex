defmodule AndiWeb.Router do
  use AndiWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", AndiWeb do
    pipe_through :api

    put "/v1/dataset", DatasetController, :create
  end

  scope "/", AndiWeb do
    pipe_through(:browser)

    get("/healthcheck", HealthCheckController, :index)
  end
end
