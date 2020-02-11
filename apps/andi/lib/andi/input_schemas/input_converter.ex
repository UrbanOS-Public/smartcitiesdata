defmodule Andi.InputSchemas.InputConverter do
  @moduledoc """
  Used to convert between SmartCity.Datasets, form data (defined by Andi.InputSchemas.DatasetInput), and Ecto.Changesets.
  """

  alias SmartCity.Dataset
  alias Andi.InputSchemas.DatasetInput

  @type dataset :: map() | Dataset.t()

  @spec changeset_from_dataset(dataset) :: Ecto.Changeset.t()
  def changeset_from_dataset(dataset) do
    %{id: id, business: business, technical: technical} = AtomicMap.convert(dataset, safe: false, underscore: false)

    from_business = get_business(business) |> fix_modified_date()
    from_technical = get_technical(technical) |> convert_source_query_params()

    %{id: id}
    |> Map.merge(from_business)
    |> Map.merge(from_technical)
    |> DatasetInput.full_validation_changeset()
  end

  @spec changeset_from_dataset(Dataset.t(), map()) :: Ecto.Changeset.t()
  def changeset_from_dataset(%SmartCity.Dataset{} = original_dataset, changes) do
    form_data_with_atom_keys = AtomicMap.convert(changes, safe: false, underscore: false)

    original_dataset_flattened =
      original_dataset
      |> changeset_from_dataset()
      |> Ecto.Changeset.apply_changes()

    all_changes = Map.merge(original_dataset_flattened, form_data_with_atom_keys)

    all_changes
    |> adjust_form_input()
    |> DatasetInput.full_validation_changeset()
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
  end

  @spec restruct(map(), Dataset.t()) :: Dataset.t()
  def restruct(changes, dataset) do
    formatted_changes =
      changes
      |> Map.update(:issuedDate, nil, &date_to_iso8601_datetime/1)
      |> Map.update(:modifiedDate, nil, &date_to_iso8601_datetime/1)
      |> Map.update(:sourceQueryParams, [], &restruct_query_params/1)

    business = Map.merge(dataset.business, get_business(formatted_changes)) |> Map.from_struct()
    technical = Map.merge(dataset.technical, get_technical(formatted_changes)) |> Map.from_struct()

    %{}
    |> Map.put(:id, dataset.id)
    |> Map.put(:business, business)
    |> Map.put(:technical, technical)
    |> SmartCity.Dataset.new()
    |> (fn {:ok, dataset} -> dataset end).()
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

  defp restruct_query_params(params) do
    Enum.reduce(params, %{}, fn param, acc -> Map.put(acc, param.key, param.value) end)
  end

  defp convert_source_query_params(%{sourceQueryParams: nil} = technical), do: Map.put(technical, :sourceQueryParams, [])

  defp convert_source_query_params(%{sourceQueryParams: query_params} = technical) do
    converted = Enum.map(query_params, fn {k, v} -> %{key: Atom.to_string(k), value: v} end)
    Map.put(technical, :sourceQueryParams, converted)
  end

  defp convert_source_query_params(technical), do: Map.put(technical, :sourceQueryParams, [])
end
