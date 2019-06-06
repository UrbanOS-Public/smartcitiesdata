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
    do_call(conn, opts.for_params, conn.params)
  end

  def invalidate() do
    Cachex.clear(__MODULE__)
    Logger.debug(fn -> "Cache cleared" end)
  end

  defp do_call(conn, for_params, actual_params) when for_params == actual_params do
    case Cachex.get(__MODULE__, {conn.request_path, conn.params}) do
      {:ok, nil} ->
        conn
        |> register_hook()

      {:ok, response} ->
        Logger.debug(fn -> "Responding to #{conn.request_path} / #{conn.params} with entry from cache" end)

        conn
        |> merge_resp_headers(response.resp_headers)
        |> send_resp(200, response.resp_body)
        |> halt()
    end
  end

  defp do_call(conn, _for_params, _params) do
    conn
  end

  defp register_hook(conn) do
    register_before_send(conn, fn conn ->
      Cachex.put(__MODULE__, {conn.request_path, conn.params}, %{resp_headers: conn.resp_headers, resp_body: conn.resp_body})
      conn
    end)
  end
end
