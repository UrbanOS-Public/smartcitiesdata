defmodule DiscoveryApi.Schemas.Visualizations do
  @moduledoc """
  Interface for reading and writing the Visualization schema.
  """

  import Ecto.Query, only: [from: 2]

  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.Visualizations.Visualization

  def list_visualizations do
    Repo.all(Visualization)
  end

  def create_visualization(visualization_attributes) do
    query = Map.get(visualization_attributes, :query)

    %Visualization{}
    |> add_used_datasets(query)
    |> Visualization.changeset(visualization_attributes)
    |> Repo.insert()
  end

  def delete_visualization(visualization) do
    Repo.delete(visualization)
  end

  def get_visualization_by_id(public_id) do
    case Repo.get_by(Visualization, public_id: public_id) |> Repo.preload(:owner) do
      nil -> {:error, "#{public_id} not found"}
      visualization -> {:ok, visualization}
    end
  end

  def get_visualizations_by_owner_id(owner_id) do
    query =
      from(visualization in Visualization,
        where: visualization.owner_id == ^owner_id
      )

    Repo.all(query)
  end

  def update_visualization_by_id(id, visualization_changes, user) do
    {:ok, existing_visualization} = get_visualization_by_id(id)

    if user.id == existing_visualization.owner_id do
      visualization_changes = add_used_datasets(visualization_changes, Map.get(visualization_changes, :query))

      existing_visualization
      |> Visualization.changeset_update(visualization_changes)
      |> Repo.update()
    else
      {:error, "User does not have permission to update this visualization."}
    end
  end

  defp add_used_datasets(visualization, nil), do: visualization

  defp add_used_datasets(visualization, query) do
    DiscoveryApi.prestige_opts()
    |> Prestige.new_session()
    |> Prestige.query("EXPLAIN (TYPE IO, FORMAT JSON) #{query}")
    |> handle_explain_response(visualization)
  end

  defp handle_explain_response({:ok, response}, visualization) do
    datasets =
      response
      |> Map.get(:rows)
      |> Jason.decode!()
      |> Map.get("inputTableColumnInfos")
      |> Enum.map(fn %{"table" => %{"schemaTable" => %{"table" => table}}} -> table end)
      |> get_dataset_ids()

    visualization
    |> Map.put(:datasets, datasets)
    |> Map.put(:valid_query, true)
  end

  defp handle_explain_response({:error, _}, visualization) do
    visualization
    |> Map.put(:datasets, [])
    |> Map.put(:valid_query, false)
  end

  defp get_dataset_ids(system_names) do
    Brook.get_all_values!(DiscoveryApi.instance(), :models)
    |> Enum.filter(fn %{systemName: system_name} -> system_name in system_names end)
    |> Enum.map(fn %{id: id} -> id end)
  end
end
