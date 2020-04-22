defmodule Andi.InputSchemas.DataDictionaryFields do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.Repo

  import Ecto.Query

  require Logger

  @top_level_bread_crumb "Top Level"

  def add_field_to_parent(original_field, parent_bread_crumb) do
    updated_field = adjust_parent_details(original_field, parent_bread_crumb)
    changeset = DataDictionary.changeset(%DataDictionary{}, updated_field)

    case Repo.insert_or_update(changeset) do
      {:error, _changeset} ->
        {:error, DataDictionary.changeset(%DataDictionary{}, original_field)}

      good ->
        good
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
    top_level_parent = [{@top_level_bread_crumb, dataset.technical.id}]

    data_dictionary_query =
      from(saved_dataset in Dataset,
        join: data_dictionary in DataDictionary,
        on: data_dictionary.dataset_id == saved_dataset.id,
        where: data_dictionary.type in ["map", "list"] and saved_dataset.id == ^dataset_id,
        select: {data_dictionary.bread_crumb, data_dictionary.id}
      )

    data_dictionary_results = Repo.all(data_dictionary_query)

    top_level_parent ++ data_dictionary_results
  end
end
