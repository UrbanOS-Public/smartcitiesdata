defmodule EstuaryWeb.Router do
  use EstuaryWeb, :router

  @csp "default-src 'self';" <>
         "style-src 'self' 'unsafe-inline' 'unsafe-eval' https://fonts.googleapis.com;" <>
         "script-src 'self' 'unsafe-inline' 'unsafe-eval';" <>
         "font-src https://fonts.gstatic.com data: 'self';" <>
         "img-src 'self' data:;"

  pipeline :browser do
    plug(Plug.Logger)
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers, %{"content-security-policy" => @csp})
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(Plug.Logger)
  end

  scope "/", EstuaryWeb do
    pipe_through(:browser)

    get("/", Redirect, to: "/events")
    live("/events", EventLiveView)
  end

  scope "/api", EstuaryWeb.API do
    pipe_through(:api)

    get("/v1/events", EventController, :get_all)
  end
end
