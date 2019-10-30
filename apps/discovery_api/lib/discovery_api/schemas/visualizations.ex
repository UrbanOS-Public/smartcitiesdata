defmodule DiscoveryApi.Schemas.Visualizations do
  @moduledoc """
  Interface for reading and writing the Visualization schema.
  """
  alias DiscoveryApi.Repo
  alias Ecto.Changeset
  alias DiscoveryApi.Schemas.Visualizations.Visualization

  def list_visualizations do
    Repo.all(Visualization)
  end

  def create(visualization_attributes) do
    %Visualization{}
    |> Visualization.changeset(visualization_attributes)
    |> Repo.insert()
  end

  def get_visualization(public_id) do
    case Repo.get_by(Visualization, public_id: public_id) |> Repo.preload(:owner) do
      nil -> {:error, "#{public_id} not found"}
      visualization -> {:ok, visualization}
    end
  end

  def update(visualization_changes, caller, opts \\ []) do
    {:ok, existing_visualization} = get_visualization(visualization_changes["public_id"])

    if caller == existing_visualization.owner do
      existing_visualization
      |> Visualization.changeset_update(visualization_changes) |> IO.inspect(label: "changeset")
      |> Repo.update(opts)
    else
      :error
    end
  end
end
