defmodule DiscoveryApiWeb.DataJsonController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Data.Model

  def get_data_json(conn, _params) do
    case Model.get_all() |> Enum.filter(&is_public?/1) do
      [] ->
        render_error(conn, 404, "Not Found")

      result ->
        render(
          conn,
          :get_data_json,
          models: result,
          base_url: determine_base_url()
        )
    end
  end

  defp is_public?(%Model{} = model) do
    model.private == false
  end

  defp determine_base_url() do
    host =
      Application.get_env(
        :discovery_api,
        DiscoveryApiWeb.Endpoint
      )[:url][:host]

    "https://data.#{host}"
  end
end
