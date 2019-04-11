defmodule DiscoveryApiWeb.Plugs.GetDataset do
  @moduledoc false

  require Logger
  import Plug.Conn

  alias DiscoveryApi.Data.{Dataset, SystemNameCache}

  def init(default), do: default

  def call(%{params: %{"org_name" => org_name, "dataset_name" => dataset_name}} = conn, _) do
    with dataset_id when not is_nil(dataset_id) <- SystemNameCache.get(org_name, dataset_name),
         dataset when not is_nil(dataset) <- Dataset.get(dataset_id) do
      assign(conn, :dataset, dataset)
    else
      _ -> render_404(conn)
    end
  end

  def call(%{params: %{"dataset_id" => dataset_id}} = conn, _) do
    case Dataset.get(dataset_id) do
      dataset when not is_nil(dataset) -> assign(conn, :dataset, dataset)
      nil -> render_404(conn)
    end
  end

  defp render_404(conn) do
    conn
    |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found")
    |> halt()
  end
end
