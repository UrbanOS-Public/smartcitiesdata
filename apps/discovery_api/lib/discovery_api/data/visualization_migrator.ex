defmodule DiscoveryApi.Data.VisualizationMigrator do
  @moduledoc """
  Module to ensure all derived fields of visualizations are up to date.
  """
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Schemas.Visualizations.Visualization

  use GenServer, restart: :transient

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    DiscoveryApi.Repo.get_by(Visualization, valid_query: nil)
    |> Enum.map(&update_visualization/1)

    {:ok, nil, {:continue, :stop}}
  end

  def handle_continue(:stop, _) do
    {:stop, :normal, nil}
  end

  defp update_visualization(%{public_id: public_id, owner: owner} = visualization) do
    Visualizations.update_visualization_by_id(public_id, visualization, owner)
  end
end
