defmodule DiscoveryApi.Schemas.Visualizations do
  @moduledoc """
  Interface for reading and writing the Visualization schema.
  """
  alias DiscoveryApi.Repo
  alias DiscoveryApi.Schemas.Visualizations.Visualization

  def list_visualizations do
    Repo.all(Visualization)
  end

  def create(visualization_attributes) do
    %Visualization{}
    |> Visualization.changeset(visualization_attributes)
    |> Repo.insert()
  end

  def get_visualization(id) do
    case Repo.get_by(Visualization, public_id: id) do
      nil -> {:error, "#{id} not found"}
      visualization -> {:ok, visualization}
    end
  end

  def update(id, visualization_changes, opts \\ []) do
    {:ok, existing_visualization} = get_visualization(id)

    existing_visualization
    |> Visualization.changeset(visualization_changes)
    |> Repo.update(opts)
  end
end
