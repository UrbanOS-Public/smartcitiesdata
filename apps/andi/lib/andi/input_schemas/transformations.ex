defmodule Andi.InputSchemas.Transformations do
  @moduledoc false
  alias Andi.InputSchemas.Ingestions.Transformation
  alias Andi.Repo
  alias Andi.InputSchemas.StructTools

  import Ecto.Query, only: [from: 2]

  require Logger

  def create(new_transformation_changes) do
    changes =
      new_transformation_changes
      |> Transformation.changeset()
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()

    update(%Transformation{}, changes)
  end

  def get(transformation_id) do
    Repo.get(Transformation, transformation_id)
    |> Transformation.preload()
  end

  def all_for_ingestion(ingestion_id) do
    query =
      from(extract_step in Transformation,
        where: extract_step.ingestion_id == ^ingestion_id
      )

    Repo.all(query)
  end

  def update(changes) do
    from_transformation =
      case get(changes.id) do
        nil -> %Transformation{}
        struct -> struct
      end

    update(from_transformation, changes)
  end

  def update(from_transformation, changes) do
    changes_as_map = StructTools.to_map(changes)

    from_transformation
    |> Transformation.changeset_for_draft(changes_as_map)
    |> Repo.insert_or_update()
  end

  def delete(transformation_id) do
    Repo.delete(%Transformation{id: transformation_id})
  end
end
