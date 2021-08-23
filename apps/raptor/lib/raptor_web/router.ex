defmodule RaptorWeb.Router do
  use RaptorWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", RaptorWeb do
    pipe_through :browser
  end
end
