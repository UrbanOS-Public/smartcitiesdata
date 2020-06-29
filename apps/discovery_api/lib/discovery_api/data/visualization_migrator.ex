defmodule DiscoveryApi.Data.VisualizationMigrator do
  @moduledoc """
  Module to ensure all derived fields of visualizations are up to date.
  """
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Schemas.Visualizations.Visualization

  use GenServer, restart: :transient

  import Ecto.Query, only: [from: 2]

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil)
  end

  def init(_) do
    {:ok, nil, {:continue, :run}}
  end

  def handle_continue(:stop, _) do
    {:stop, :normal, nil}
  end

  def handle_continue(:run, _) do
    case migrate() do
      :ok ->
        Logger.info("Visualization Migration Successful")
        {:noreply, nil, {:continue, :stop}}

      :error ->
        Logger.info("Visualization Migration Failed. Retrying.")
        Process.sleep(2000)
        {:noreply, nil, {:continue, :run}}
    end
  end

  defp migrate() do
    try do
      Visualizations.get_visualizations_to_be_migrated()
      |> Enum.each(&update_visualization/1)

      :ok
    rescue
      _ -> :error
    end
  end

  defp update_visualization(%{public_id: public_id, owner: owner} = visualization) do
    Visualizations.update_visualization_by_id(public_id, visualization, owner)
  end
end
