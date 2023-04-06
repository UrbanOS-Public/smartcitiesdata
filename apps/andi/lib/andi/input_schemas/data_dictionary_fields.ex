defmodule Andi.InputSchemas.DataDictionaryFields do
  @moduledoc false
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Ingestions
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.Repo
  alias Ecto.Changeset

  import Ecto.Query

  require Logger

  @top_level_bread_crumb "Top Level"

  def add_field_to_parent(new_field, parent_bread_crumb) do
    new_field_updated = adjust_parent_details(new_field, parent_bread_crumb)
    changeset = DataDictionary.changeset_for_new_field(%DataDictionary{}, new_field_updated)

    case Repo.insert_or_update(changeset) do
      {:error, _} ->
        {:error, DataDictionary.changeset_for_new_field(%DataDictionary{}, new_field)}

      good ->
        good
    end
  end

  def add_field_to_parent_for_ingestion(new_field, parent_bread_crumb) do
    new_field_updated = adjust_parent_details_for_ingestion(new_field, parent_bread_crumb)
    changeset = DataDictionary.ingestion_changeset_for_new_field(%DataDictionary{}, new_field_updated)

    case Repo.insert_or_update(changeset) do
      {:error, _} ->
        {:error, DataDictionary.ingestion_changeset_for_new_field(%DataDictionary{}, new_field)}

      good ->
        good
    end
  end

  def remove_field(existing_field_id) do
    existing_field = Repo.get(DataDictionary, existing_field_id)

    if existing_field != nil do
      case Repo.delete(existing_field) do
        {:error, _} ->
          {:error, DataDictionary.changeset_for_new_field(%DataDictionary{}, existing_field)}

        good ->
          good
      end
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

  def ingestion_get_parent_ids(changeset, ingestion_id) do
    top_level_parent = [{@top_level_bread_crumb, ingestion_id}]
    schema = case Changeset.fetch_field(changeset, :schema) do
      {_, schema} -> schema
      :error -> []
    end

    get_parent_ids_from_ingestion(schema, top_level_parent) |> Enum.reverse()
  end

  def get_parent_ids_from_ingestion(ingestion) do
    top_level_parent = [{@top_level_bread_crumb, ingestion.id}]
    updated_ingestion = Ingestions.get(ingestion.id)
    get_parent_ids_from_ingestion(updated_ingestion.schema, top_level_parent) |> Enum.reverse()
  end

  defp get_parent_ids_from_ingestion(schema, ids) do
    parents = schema |> Enum.filter(fn schema -> schema.type in ["map", "list"] end)

    case parents do
      [] ->
        ids

      parents ->
        parents
        |> Enum.reduce(
          ids,
          fn parent, ids ->
            get_parent_ids_from_ingestion(parent.subSchema, [{parent.bread_crumb, parent.id} | ids])
          end
        )
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

  defp adjust_parent_details_for_ingestion(field, parent_bread_crumb) do
    case parent_bread_crumb do
      @top_level_bread_crumb ->
        {_id, field} = Map.pop(field, :parent_id)

        Map.put(field, :bread_crumb, field.name)

      _ ->
        field
        |> Map.put(:bread_crumb, parent_bread_crumb <> " > " <> field.name)
    end
  end
end
