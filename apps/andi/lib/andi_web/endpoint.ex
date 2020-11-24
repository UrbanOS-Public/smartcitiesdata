defmodule AndiWeb.Endpoint do
  @session_options [
    store: :cookie,
    key: "_andi_key",
    signing_salt: "SekoFX7T"
  ]

  use Phoenix.Endpoint, otp_app: :andi


  plug Plug.Static,
    at: "/",
    from: :andi,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
  end

  plug :enforce_access_level

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.RequestId

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session, @session_options

  plug AndiWeb.Router

  def enforce_access_level(conn, _opts) do
    %{plug: plug, plug_opts: plug_opts} = Phoenix.Router.route_info(AndiWeb.Router, conn.method, conn.path_info, conn.host)

    plug =
      case plug == Phoenix.LiveView.Plug do
        true -> plug_opts
        false -> plug
      end

    with true <- function_exported?(plug, :access_levels_supported, 1),
         true <- Application.get_env(:andi, :access_level) in apply(plug, :access_levels_supported, [plug_opts]) do
      conn
    else
      _ ->
        Plug.Conn.resp(conn, 404, "Not found")
        |> Plug.Conn.halt()
    end
  end
end
