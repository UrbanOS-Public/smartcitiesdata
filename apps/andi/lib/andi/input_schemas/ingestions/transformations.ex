defmodule Andi.InputSchemas.Ingestions.Transformations do
  @moduledoc false

  alias Andi.Repo
  alias Ecto.Changeset
  alias Andi.InputSchemas.Ingestions.Transformation
  alias Andi.InputSchemas.StructTools

  require Logger

  def get(id), do: Repo.get(Transformation, id)

  def get_all(), do: Repo.all(Transformation)

  def create() do

    changeset =
      Transformation.changeset_for_draft(%{
        id: UUID.uuid4()
      })

    {:ok, _} = save(changeset)
    changeset
  end

  def delete(transformation_id) do
    Repo.delete(%Transformation{id: transformation_id})
  rescue
    _e in Ecto.StaleEntryError ->
      {:error, "attempted to remove a transformation (id: #{transformation_id}) that does not exist."}
  end

  def update(%Transformation{} = transformation) do
    original_transformation =
      case get(transformation.id) do
        nil -> %Transformation{}
        transformation -> transformation
      end

    update(original_transformation, transformation)
  end

  def update(%Transformation{} = from_transformation, changes) do
    changes_as_map = StructTools.to_map(changes)

    Transformation.changeset(from_transformation, changes_as_map)
    |> save()
  end

  def save(%Changeset{} = changeset) do
    Repo.insert_or_update(changeset)
  end
end
