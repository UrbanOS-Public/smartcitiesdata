defmodule CotaStreamingConsumerWeb.Router do
  use CotaStreamingConsumerWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", CotaStreamingConsumerWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/socket/healthcheck", HealthCheckController, :index)
    get("/socket/nodelist", NodelistController, :index)
  end

  # Other scopes may use custom stacks.
  # scope "/api", HelloWeb do
  #   pipe_through :api
  # end
end
