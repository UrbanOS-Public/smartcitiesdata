defmodule DiscoveryApiWeb.DataJsonController do
  @moduledoc """
  Controller for returning Project Open Data Metadata Schema (podms) information.
  """

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
          models: result
        )
    end
  end

  defp is_public?(%Model{} = model) do
    model.private == false
  end
end
