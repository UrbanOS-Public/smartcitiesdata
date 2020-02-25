defmodule DiscoveryApiWeb.Plugs.ResponseCache do
  @moduledoc """
  Plug that will cache responses for configured url patterns
  """
  import Plug.Conn
  require Logger

  def child_spec([]) do
    Supervisor.child_spec({Cachex, __MODULE__}, id: __MODULE__)
  end

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    do_call(conn, conn.params in opts.for_params)
  end

  def invalidate() do
    Cachex.clear(__MODULE__)
    Logger.debug(fn -> "Cache cleared" end)
  end

  defp do_call(conn, true = _match) do
    case Cachex.get(__MODULE__, {conn.request_path, conn.params}) do
      {:ok, nil} ->
        conn
        |> register_hook()

      {:ok, response} ->
        Logger.debug(fn -> "Responding to #{conn.request_path} / #{inspect(conn.params)} with entry from cache" end)

        conn
        |> merge_resp_headers(response.resp_headers)
        |> send_resp(200, response.resp_body)
        |> halt()
    end
  end

  defp do_call(conn, false = _match) do
    conn
  end

  defp register_hook(conn) do
    register_before_send(conn, fn conn ->
      Cachex.put(__MODULE__, {conn.request_path, conn.params}, %{resp_headers: content_headers(conn), resp_body: conn.resp_body})
      conn
    end)
  end

  defp content_headers(conn) do
    conn.resp_headers
    |> Enum.filter(fn {name, _value} -> String.starts_with?(name, "content-") end)
  end
end
