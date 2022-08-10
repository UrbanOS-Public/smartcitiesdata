defmodule DiscoveryApiWeb.Endpoint.Instrumenter do
  @moduledoc false
end

defmodule DiscoveryApiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :discovery_api

  socket("/socket", DiscoveryApiWeb.UserSocket)

  plug(PlugHeartbeat, path: "/healthcheck")

  plug(DiscoveryApiWeb.Plugs.SecureHeaders)

  plug(Corsica,
    origins: "*",
    allow_credentials: true,
    allow_headers: ["authorization", "content-type"],
    expose_headers: ["token"]
  )

  # if Application.get_env(:discovery_api, :hsts_enabled, true) do
  #   plug(Plug.SSL,
  #     hsts: true,
  #     expires: 63_072_000,
  #     subdomains: true,
  #     preload: true,
  #     rewrite_on: [:x_forwarded_proto]
  #   )
  # end

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug(
    Plug.Static,
    at: "/",
    from: :discovery_api,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt tableau)
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(
    Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Poison
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug(
    Plug.Session,
    store: :cookie,
    key: "_discovery_api_key",
    signing_salt: "foI/nCz1"
  )

  plug(DiscoveryApiWeb.Router)

  @doc """
  Callback invoked for dynamically configuring the endpoint.

  It receives the endpoint configuration and checks if
  configuration should be loaded from the system environment.
  """
  def init(_key, config) do
    if config[:load_from_system_env] do
      port = System.get_env("PORT") || raise "expected the PORT environment variable to be set"
      {:ok, Keyword.put(config, :http, [:inet6, port: port])}
    else
      {:ok, config}
    end
  end
end
