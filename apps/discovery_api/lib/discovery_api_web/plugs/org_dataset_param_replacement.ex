defmodule DiscoveryApiWeb.Plugs.OrgDatasetParamReplacement do
  @moduledoc """
  Plug that will replace org_name and dataset_name parameters with
  the dataset_id.
  """
  @behaviour Plug
  import Plug.Conn
  require Logger

  alias DiscoveryApi.Data.SystemNameCache

  def init(_opts), do: false

  def call(%Plug.Conn{params: %{"org_name" => org_name, "dataset_name" => dataset_name}} = conn, _opts) do
    case SystemNameCache.get(org_name, dataset_name) do
      nil -> return_404(conn)
      dataset_id -> replace_params(conn, dataset_id)
    end
  end

  def call(conn, _opts), do: conn

  defp replace_params(conn, dataset_id) do
    new_params =
      conn.params
      |> Map.put("dataset_id", dataset_id)
      |> Map.delete("org_name")
      |> Map.delete("dataset_name")

    %{conn | params: new_params}
  end

  defp return_404(conn) do
    conn
    |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found")
    |> halt()
  end
end
