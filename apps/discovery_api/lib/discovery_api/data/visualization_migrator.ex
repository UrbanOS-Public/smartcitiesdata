defmodule DiscoveryApi.Data.VisualizationMigrator do
  @moduledoc """
  Module to ensure all derived fields of visualizations are up to date.
  """
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Repo

  use GenServer, restart: :transient

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
      error ->
        Logger.error(inspect(error))
        :error
    end
  end

  defp update_visualization(%{public_id: public_id} = visualization) do
    destructed_visualization =
      visualization
      |> Repo.preload(:owner)
      |> Map.from_struct()

    {:ok, owner_with_orgs} = Users.get_user_with_organizations(destructed_visualization.owner.id)
    Visualizations.update_visualization_by_id(public_id, destructed_visualization, owner_with_orgs)
  end
end
