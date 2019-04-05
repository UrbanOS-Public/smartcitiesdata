defmodule DiscoveryApi.Plugs.GetDataset do
  @moduledoc false

  require Logger
  import Plug.Conn
  alias DiscoveryApi.Auth.Guardian

  alias SmartCity.Organization
  alias DiscoveryApi.Data.Dataset

  def init(default), do: default

  def call(conn, _) do
    with %{"dataset_id" => dataset_id} <- Map.get(conn, :path_params),
         dataset when not is_nil(dataset) <- Dataset.get(dataset_id) do
      conn
      |> assign(:dataset, dataset)
    else
      nil ->
        conn
        |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found")
        |> halt()
    end
  end
end
