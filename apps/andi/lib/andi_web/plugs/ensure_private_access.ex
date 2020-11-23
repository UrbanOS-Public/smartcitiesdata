defmodule AndiWeb.Plug.EnsurePrivateAccess do
  @moduledoc """
  Halts further connectivity if private access is not enabled
  """
  import Plug.Conn

  def init(opts) do
    if Keyword.has_key?(opts, :target) do
      opts
    else
      raise("Missing required option ':target' in redirect")
    end
  end

  def call(conn, opts) do
    if Andi.private_access?() do
      conn
    else
      conn
      |> put_status(404)
      |> render_error(Keyword.get(opts, :target))
      |> halt()
    end
  end

  defp render_error(conn, :browser) do
    Phoenix.Controller.put_view(conn, AndiWeb.ErrorView)
    |> Phoenix.Controller.render("404.html")
  end

  defp render_error(conn, :api)do
    Phoenix.Controller.json(conn, "Not found")
  end
end
