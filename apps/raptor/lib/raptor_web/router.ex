defmodule RaptorWeb.Router do
  use RaptorWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", RaptorWeb do
    pipe_through :api
    get("/authorize", AuthorizeController, :authorize)
    get("/listAccessGroups", ListAccessGroupsController, :list)
    get("/getUserIdFromApiKey", ApiKeyController, :getUserIdFromApiKey)
    patch("/regenerateApiKey", ApiKeyController, :regenerateApiKey)
    get("/checkRole", ApiKeyController, :checkRole)
  end
end
