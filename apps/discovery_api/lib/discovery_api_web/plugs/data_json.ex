defmodule DiscoveryApiWeb.Plugs.DataJson do
  @moduledoc false
  use Plug.Builder
  use Plug.Debugger, otp_app: :discovery_api
  alias DiscoveryApi.Services.DataJsonService

  plug :init, service: Application.get_env(:discovery_api, :data_json_service)

  def init(conn, opts) do
    case opts[:service] do
      :local ->
        # Service to serve local file
        case DataJsonService.ensure_data_json_file() do
          {:ok, file_path} -> conn |> Plug.Conn.put_resp_header("content-type", "application/json") |> Plug.Conn.send_file(200, file_path)
          {:error, _} -> conn |> Plug.Conn.resp(500, "Internal Server Error") |> Plug.Conn.send_resp()
        end

      _ ->
        # 404 error
        conn |> Plug.Conn.resp(404, "Not Found") |> Plug.Conn.send_resp()
    end
  end

  def delete_data_json() do
    case Application.get_env(:discovery_api, :data_json_service) do
      :local -> DataJsonService.delete_data_json()
    end
  end
end
