defmodule AndiWeb.Router do
  use AndiWeb, :router

  pipeline :browser do
    plug Plug.Logger
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug Plug.Logger
  end

  scope "/", AndiWeb do
    pipe_through :browser

    get "/", Redirect, to: "/datasets"
    resources "/datasets", DatasetPageController, only: [:index]
  end

  scope "/api", AndiWeb do
    pipe_through :api

    get "/v1/datasets", DatasetController, :get_all
    get "/v1/dataset/:dataset_id", DatasetController, :get
    put "/v1/dataset", DatasetController, :create
    post "/v1/dataset/disable", DatasetController, :disable
    post "/v1/dataset/delete", DatasetController, :delete
    get "/v1/organizations", OrganizationController, :get_all
    post "/v1/organization/:org_id/users/add", OrganizationController, :add_users_to_organization
    post "/v1/organization", OrganizationController, :create
    post "/v1/repost_org_updates", OrganizationController, :repost_org_updates
  end

  scope "/", AndiWeb do
    get("/healthcheck", HealthCheckController, :index)
  end
end
