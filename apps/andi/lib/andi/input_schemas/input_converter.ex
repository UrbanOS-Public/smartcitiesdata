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
    |> IO.inspect(label: "changeset_from_dataset_map")
    |> create_changeset_from_dataset()
  end

  defp create_changeset_from_dataset(%{id: id, business: business, technical: technical}) do
    from_business = get_business(business)
    from_technical = get_technical(technical)

    %{id: id}
    |> Map.merge(from_business)
    |> Map.merge(from_technical)
    |> DatasetInput.changeset()
    # TODO: test that ID is actually getting into the changeset
  end

  def form_changeset(params \\ %{})

  def form_changeset(%{keywords: keywords} = params) when is_binary(keywords) do
    params
    |> Map.update!(:keywords, &keyword_string_to_list/1)
    |> DatasetInput.changeset()
  end

  def form_changeset(%{"keywords" => keywords} = params) when is_binary(keywords) do
    params
    |> Map.update!("keywords", &keyword_string_to_list/1)
    |> DatasetInput.changeset()
  end

  def form_changeset(params), do: DatasetInput.changeset(params)

  def restruct(changes, dataset) do
    formatted_changes =
      changes
      |> Map.update!(:issuedDate, &date_to_iso8601_datetime/1)
      |> Map.update!(:modifiedDate, &date_to_iso8601_datetime/1)

    business = Map.merge(dataset.business, get_business(formatted_changes))
    technical = Map.merge(dataset.technical, get_technical(formatted_changes))

    dataset
    |> Map.put(:business, business)
    |> Map.put(:technical, technical)
  end

  defp get_business(map) when is_map(map) do
    Map.take(map, DatasetInput.business_keys())
  end

  defp get_technical(map) when is_map(map) do
    Map.take(map, DatasetInput.technical_keys())
  end

  defp keyword_string_to_list(nil), do: []
  defp keyword_string_to_list(""), do: []

  defp keyword_string_to_list(keywords) do
    keywords
    |> String.split(", ")
    |> Enum.map(&String.trim/1)
  end

  defp date_to_iso8601_datetime(date) do
    time_const = "00:00:00Z"

    "#{Date.to_iso8601(date)} #{time_const}"
  end
end
