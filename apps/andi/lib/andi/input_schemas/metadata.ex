defmodule Andi.InputSchemas.Metadata do
  @moduledoc false

  alias Andi.InputSchemas.Dataset

  def changeset_from_struct(%SmartCity.Dataset{} = dataset) do
    create_changeset_from_dataset(dataset)
  end

  def changeset_from_dataset_map(dataset) do
    AtomicMap.convert(dataset, safe: false, underscore: false)
    |> create_changeset_from_dataset()
  end

  defp create_changeset_from_dataset(%{business: business, technical: technical}) do
    from_business = get_business(business)
    from_technical = get_technical(technical)

    Map.merge(from_business, from_technical)
    |> Dataset.changeset()
  end

  def form_changeset(params \\ %{})

  def form_changeset(%{keywords: keywords} = params) when is_binary(keywords) do
    params
    |> Map.update!(:keywords, &keyword_string_to_list/1)
    |> Dataset.changeset()
  end

  def form_changeset(%{"keywords" => keywords} = params) when is_binary(keywords) do
    params
    |> Map.update!("keywords", &keyword_string_to_list/1)
    |> Dataset.changeset()
  end

  def form_changeset(params), do: Dataset.changeset(params)

  def restruct(schema, dataset) do
    formatted_schema =
      schema
      |> Map.update!(:issuedDate, &date_to_iso8601_datetime/1)
      |> Map.update!(:modifiedDate, &date_to_iso8601_datetime/1)

    business = Map.merge(dataset.business, get_business(formatted_schema))
    technical = Map.merge(dataset.technical, get_technical(formatted_schema))

    dataset
    |> Map.put(:business, business)
    |> Map.put(:technical, technical)
  end

  defp get_business(map) when is_map(map) do
    Map.take(map, Dataset.business_field_keys())
  end

  defp get_technical(map) when is_map(map) do
    Map.take(map, Dataset.technical_field_keys())
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
