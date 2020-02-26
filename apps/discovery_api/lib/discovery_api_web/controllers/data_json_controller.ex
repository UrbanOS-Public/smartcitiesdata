defmodule DiscoveryApiWeb.DataJsonController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Services.DataJsonService

  def show(conn, _params) do
    case DataJsonService.ensure_data_json_file() do
      {:local, file_path} ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_file(200, file_path)

      {:error, _} ->
        conn
        |> Plug.Conn.resp(500, "Internal Server Error")
        |> Plug.Conn.send_resp()
    end
  end
end
