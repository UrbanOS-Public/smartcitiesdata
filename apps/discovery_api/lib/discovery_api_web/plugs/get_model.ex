defmodule DiscoveryApiWeb.Plugs.GetModel do
  @moduledoc """
  Plug to get the requested dataset (by org and dataset name or by dataset id) or return 404
  """

  require Logger
  import Plug.Conn

  alias DiscoveryApi.Data.{Model, SystemNameCache}

  # Allow configuring the model module for testing
  @model_impl Application.compile_env(:discovery_api, :model, Model)

  def init(default), do: default

  def call(%{params: %{"org_name" => org_name, "dataset_name" => dataset_name}} = conn, _) do
    with dataset_id when not is_nil(dataset_id) <- SystemNameCache.get(org_name, dataset_name),
         model when not is_nil(model) <- @model_impl.get(dataset_id) do
      assign(conn, :model, model)
    else
      _ -> render_404(conn)
    end
  end

  def call(%{params: %{"dataset_id" => dataset_id}} = conn, _) do
    case @model_impl.get(dataset_id) do
      model when not is_nil(model) -> assign(conn, :model, model)
      nil -> render_404(conn)
    end
  end

  defp render_404(conn) do
    conn
    |> DiscoveryApiWeb.RenderError.render_error(404, "Not Found")
    |> halt()
  end
end
