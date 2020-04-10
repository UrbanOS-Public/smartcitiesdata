defmodule Andi.InputSchemas.DataDictionaryFields do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.Repo

  import Ecto.Query

  require Logger

  @top_level_bread_crumb "Top Level"

  def add_field_to_parent(field_as_map, parent_bread_crumb) do
    field_with_correct_foreign_key = case parent_bread_crumb do
      @top_level_bread_crumb ->
        {id, field} = Map.pop(field_as_map, :parent_id)
        Map.put(field, :technical_id, id)
        |> Map.put(:bread_crumb, field_as_map.name)
      _ ->
        field_as_map
        |> Map.put(:bread_crumb, parent_bread_crumb <> " > " <> field_as_map.name)
    end

    changeset = DataDictionary.changeset(%DataDictionary{}, field_with_correct_foreign_key)

    Repo.insert_or_update(changeset)
  end

  def get_parent_ids(dataset) do
    dataset_id = dataset.id
    top_cheddar = [{@top_level_bread_crumb, dataset.technical.id}]

    dd_query = from d in Dataset,
      join: dd in DataDictionary,
      on: dd.dataset_id == d.id,
      where: dd.type in ["map", "list"] and d.id == ^dataset_id,
      select: {dd.bread_crumb, dd.id}

    dd_results = Repo.all(dd_query)

    top_cheddar ++ dd_results
  end
end
