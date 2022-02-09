defmodule AlchemistWeb.Router do
  use AlchemistWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", AlchemistWeb do
    pipe_through :browser
  end
end
