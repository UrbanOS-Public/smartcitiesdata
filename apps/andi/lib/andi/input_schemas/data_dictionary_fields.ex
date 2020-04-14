defmodule Andi.InputSchemas.DataDictionaryFields do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.Repo

  import Ecto.Query

  require Logger

  @top_level_bread_crumb "Top Level"

  # TODO - check why saving fails
  # TODO - need to deal with hiding/showing/clearing the add field component
  # TODO - stretch goal - rename DataDictionary to DataDictionaryField
  # TODO - stretch goal - any sort of sad path for anything at all
  # TODO - manually migrate datasets from view state into repo
  # TODO - make sure estuary isn't completely busted :|
  # TODO - add tf rds module to andi-deploy

  def add_field_to_parent(original_field, parent_bread_crumb) do
    updated_field = adjust_parent_details(original_field, parent_bread_crumb)
    changeset = DataDictionary.changeset(%DataDictionary{}, updated_field)

    case Repo.insert_or_update(changeset) do
      {:error, _changeset} ->
        {:error, DataDictionary.changeset(%DataDictionary{}, original_field)}
      good -> good
    end
  end

  defp adjust_parent_details(field, parent_bread_crumb) do
    case parent_bread_crumb do
      @top_level_bread_crumb ->
        {id, field} = Map.pop(field, :parent_id)

        Map.put(field, :technical_id, id)
        |> Map.put(:bread_crumb, field.name)

      _ ->
        field
        |> Map.put(:bread_crumb, parent_bread_crumb <> " > " <> field.name)
    end
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
