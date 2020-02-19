defmodule Andi.InputSchemas.InputConverter do
  @moduledoc """
  Used to convert between SmartCity.Datasets, form data (defined by Andi.InputSchemas.DatasetInput), and Ecto.Changesets.
  """

  alias SmartCity.Dataset
  alias Andi.InputSchemas.DatasetInput

  @type dataset :: map() | Dataset.t()

  @spec changeset_from_dataset(dataset) :: Ecto.Changeset.t()
  def changeset_from_dataset(%{"id" => _} = dataset), do: atomize_dataset_map(dataset) |> changeset_from_dataset()

  def changeset_from_dataset(%{id: id, business: business, technical: technical}) do
    from_business = get_business(business) |> fix_modified_date()
    from_technical = get_technical(technical) |> convert_key_values()

    %{id: id}
    |> Map.merge(from_business)
    |> Map.merge(from_technical)
    |> DatasetInput.full_validation_changeset()
  end

  @spec changeset_from_dataset(Dataset.t(), map()) :: Ecto.Changeset.t()
  def changeset_from_dataset(%SmartCity.Dataset{} = original_dataset, changes) do
    adjusted_changes = adjust_form_input(changes)

    original_dataset_flattened =
      original_dataset
      |> changeset_from_dataset()
      |> Ecto.Changeset.apply_changes()

    all_changes = Map.merge(original_dataset_flattened, adjusted_changes)

    DatasetInput.full_validation_changeset(all_changes)
  end

  @spec form_changeset(map()) :: Ecto.Changeset.t()
  def form_changeset(params \\ %{}) do
    params
    |> adjust_form_input()
    |> DatasetInput.light_validation_changeset()
  end

  defp adjust_form_input(params) do
    params
    |> AtomicMap.convert(safe: false, underscore: false)
    |> Map.update(:keywords, nil, &keywords_to_list/1)
    |> fix_modified_date()
    |> reset_key_values()
    |> Map.update(:sourceUrl, nil, &strip_query_string/1)
  end

  @spec restruct(map(), Dataset.t()) :: Dataset.t()
  def restruct(changes, dataset) do
    formatted_changes =
      changes
      |> Map.update(:issuedDate, nil, &date_to_iso8601_datetime/1)
      |> Map.update(:modifiedDate, nil, &date_to_iso8601_datetime/1)
      |> Map.update(:sourceUrl, nil, &strip_query_string/1)
      |> restruct_key_values()

    business = Map.merge(dataset.business, get_business(formatted_changes)) |> Map.from_struct()
    technical = Map.merge(dataset.technical, get_technical(formatted_changes)) |> Map.from_struct()

    %{}
    |> Map.put(:id, dataset.id)
    |> Map.put(:business, business)
    |> Map.put(:technical, technical)
    |> SmartCity.Dataset.new()
    |> (fn {:ok, dataset} -> dataset end).()
  end

  defp atomize_dataset_map(dataset) when is_map(dataset) do
    dataset
    |> atomize_top_level()
    |> Map.update(:business, nil, &atomize_top_level/1)
    |> Map.update(:technical, nil, &atomize_top_level/1)
    |> update_in([:technical, :schema], fn schema -> Enum.map(schema, &atomize_top_level/1) end)
  end

  defp atomize_top_level(map) do
    Map.new(map, fn {key, val} -> {SmartCity.Helpers.safe_string_to_atom(key), val} end)
  end

  defp get_business(map) when is_map(map) do
    Map.take(map, DatasetInput.business_keys())
  end

  defp get_technical(map) when is_map(map) do
    Map.take(map, DatasetInput.technical_keys())
  end

  defp keywords_to_list(nil), do: []
  defp keywords_to_list(""), do: []

  defp keywords_to_list(keywords) when is_binary(keywords) do
    keywords
    |> String.split(", ")
    |> Enum.map(&String.trim/1)
  end

  defp keywords_to_list(keywords) when is_list(keywords), do: keywords

  defp date_to_iso8601_datetime(date) do
    time_const = "00:00:00Z"

    "#{Date.to_iso8601(date)} #{time_const}"
  end

  defp fix_modified_date(map) do
    map
    |> Map.get_and_update(:modifiedDate, fn
      "" -> {"", nil}
      current_value -> {current_value, current_value}
    end)
    |> elem(1)
  end

  defp reset_key_values(map) do
    Enum.reduce(DatasetInput.key_value_keys(), map, fn field, acc ->
      Map.put_new(acc, field, %{})
    end)
  end

  defp convert_key_values(map) do
    Enum.reduce(DatasetInput.key_value_keys(), map, fn field, acc -> convert_key_values(acc, field) end)
  end

  defp convert_key_values(map, field) do
    Map.update(map, field, [], fn key_values ->
      Enum.map(key_values, fn {k, v} -> %{key: k, value: v} end)
    end)
  end

  defp restruct_key_values(map) do
    Enum.reduce(DatasetInput.key_value_keys(), map, fn field, acc -> restruct_key_values(acc, field) end)
  end

  defp restruct_key_values(map, field) do
    Map.update(map, field, %{}, fn key_values ->
      Enum.reduce(key_values, %{}, fn entry, acc -> Map.put(acc, entry.key, entry.value) end)
    end)
  end

  defp strip_query_string(url_string), do: url_string |> String.split("?") |> hd()
end
