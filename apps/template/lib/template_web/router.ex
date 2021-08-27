defmodule TemplateWeb.Router do
  use TemplateWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TemplateWeb do
    pipe_through :browser
  end
end
