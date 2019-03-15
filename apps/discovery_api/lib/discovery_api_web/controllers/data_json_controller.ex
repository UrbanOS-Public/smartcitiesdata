defmodule DiscoveryApiWeb.DataJsonController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Data.ProjectOpenData

  def get_data_json(conn, _params) do
    case ProjectOpenData.get_all() do
      nil -> render_error(conn, 404, "Not Found")
      result -> render(conn, :get_data_json, datasets: result)
    end
  end
end
