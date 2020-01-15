defmodule Andi.InputSchemas.InputConverter do
  @moduledoc false

  alias Andi.InputSchemas.DatasetInput

  def get_new_changeset(%SmartCity.Dataset{} = original_dataset, changes) when is_map(changes) do
    form_data_with_atom_keys = AtomicMap.convert(changes, safe: false, underscore: false)

    original_dataset_flattened =
      original_dataset
      |> changeset_from_struct()
      |> Ecto.Changeset.apply_changes()

    all_changes = Map.merge(original_dataset_flattened, form_data_with_atom_keys)
    form_changeset(all_changes)
  end

  def changeset_from_struct(%SmartCity.Dataset{} = dataset) do
    create_changeset_from_dataset(dataset)
  end

  def changeset_from_dataset_map(dataset) do
    AtomicMap.convert(dataset, safe: false, underscore: false)
    |> create_changeset_from_dataset()
  end

  defp create_changeset_from_dataset(%{id: id, business: business, technical: technical}) do
    from_business = get_business(business) |> fix_modified_date()
    from_technical = get_technical(technical)

    %{id: id}
    |> Map.merge(from_business)
    |> Map.merge(from_technical)
    |> DatasetInput.changeset()
  end

  def form_changeset(params \\ %{}) do
    params
    |> AtomicMap.convert(safe: false, underscore: false)
    |> Map.update(:keywords, nil, &keywords_to_list/1)
    |> fix_modified_date()
    |> DatasetInput.changeset()
  end

  def restruct(changes, dataset) do
    formatted_changes =
      changes
      |> Map.update!(:issuedDate, &date_to_iso8601_datetime/1)
      |> Map.update(:modifiedDate, nil, &date_to_iso8601_datetime/1)

    business = Map.merge(dataset.business, get_business(formatted_changes)) |> Map.from_struct()
    technical = Map.merge(dataset.technical, get_technical(formatted_changes)) |> Map.from_struct()

    dataset
    |> Map.from_struct()
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
end
