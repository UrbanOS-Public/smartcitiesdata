defmodule AndiWeb.Auth.EnsureAccessLevelForRoute do
  @moduledoc """
  Ensures that target controllers and live views have opted-in for the current access level
  """

  import Plug.Conn

  def init(opts) do
    if Keyword.has_key?(opts, :router) do
      opts
    else
      raise("Missing required option ':router'")
    end
  end

  def call(conn, opts) do
    router = Keyword.fetch!(opts, :router)
    exclusions = Keyword.get(opts, :exclusions, [])

    with %{plug: plug, plug_opts: plug_opts} <- Phoenix.Router.route_info(router, conn.method, conn.path_info, conn.host),
         {controller, action} = resolve_controllers(plug, plug_opts),
         {:excluded, false} <- {:excluded, plug in exclusions},
         true <- function_exported?(controller, :access_levels_supported, 1),
         true <- access_level() in apply(controller, :access_levels_supported, [action]) do
      conn
    else
      {:excluded, true} -> conn
      _ ->
        resp(conn, 404, "Not found")
        |> halt()
    end
  end

  defmacro access_levels(opts \\ []) do
    quote do
      def access_levels_supported(action) do
        action_levels = unquote(opts)

        Keyword.get(action_levels, action, [])
      end
    end
  end

  defp resolve_controllers(plug, plug_opts) do
    case plug == Phoenix.LiveView.Plug do
      true -> {plug_opts, :render}
      false -> {plug, plug_opts}
    end
  end

  defp access_level() do
    Application.get_env(:andi, :access_level)
  end
end
