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
    %Visualization{}
    |> add_used_datasets(visualization_attributes)
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
      existing_visualization
      |> Visualization.changeset_update(visualization_changes)
      |> Repo.update()
    else
      {:error, "User does not have permission to update this visualization."}
    end
  end

  def add_used_datasets(visualization, %{query: query}) do
    datasets = DiscoveryApi.prestige_opts()
    |> Prestige.new_session()
    |> Prestige.query("EXPLAIN (TYPE IO, FORMAT JSON) #{query}")
    |> handle_explain_response()

    Map.put(visualization, :datasets, datasets)
  end

  def add_used_datasets(visualization, _), do: Map.put(visualization, :datasets, [])

  def handle_explain_response({:ok, response}) do
    response
    |> Map.get(:rows)
    |> Jason.decode!()
    |> Map.get("inputTableColumnInfos")
    |> Enum.map(fn %{"table" => %{"schemaTable" => %{"table" => table}}} -> table end)
  end

  def handle_explain_response({:error, _}), do: []
end
