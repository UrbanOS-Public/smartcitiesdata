defmodule AndiWeb.InputSchemas.Metadata do
  @moduledoc false
  import Ecto.Changeset

  @business_fields %{
    contactEmail: :string,
    contactName: :string,
    dataTitle: :string,
    description: :string,
    homepage: :string,
    issuedDate: :date,
    keywords: {:array, :string},
    language: :string,
    license: :string,
    modifiedDate: :date, #TODO: consider converting to :utc_datetime?
    orgTitle: :string,
    publishFrequency: :string,
    spatial: :string,
    temporal: :string
  }

  @technical_fields %{
    private: :boolean,
    sourceFormat: :string
  }

  @types Map.merge(@business_fields, @technical_fields)

  @email_regex ~r/^[A-Za-z0-9._%+-+']+@[A-Za-z0-9.-]+\.[A-Za-z]+$/

  def changeset_from_struct(%SmartCity.Dataset{} = dataset) do
    create_changeset_from_struct(dataset)
  end

  def changeset_from_dataset_map(dataset) do
    AtomicMap.convert(dataset, safe: false, underscore: false)
    |> create_changeset_from_struct()
  end

  defp create_changeset_from_struct(%{business: business, technical: technical}) do
    from_business = get_business(business)
    from_technical = get_technical(technical)

    Map.merge(from_business, from_technical)
    |> new_changeset()
  end

  def form_changeset(params \\ %{})

  def form_changeset(%{keywords: keywords} = params) when is_binary(keywords) do
    params
    |> Map.update!(:keywords, &keyword_string_to_list/1)
    |> new_changeset()
  end

  def form_changeset(%{"keywords" => keywords} = params) when is_binary(keywords) do
    params
    |> Map.update!("keywords", &keyword_string_to_list/1)
    |> new_changeset()
  end

  def form_changeset(params), do: new_changeset(params)

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

  @changeset_base {%{}, @types}
  def new_changeset(params \\ %{}), do: changeset(@changeset_base, params)

  def changeset(changeset, params \\ %{}) do
    changeset
    |> cast(params, Map.keys(@types))
    |> validate_required([:dataTitle], message: "Dataset Title is required.")
    |> validate_required([:description], message: "Description is required.")
    |> validate_required([:contactName], message: "Maintainer Name is required.")
    |> validate_required([:contactEmail], message: "Maintainer Email is required.")
    |> validate_format(:contactEmail, @email_regex, message: "Email is invalid.")
    |> validate_required([:issuedDate], message: "Release Date is required.")
    |> validate_required([:license], message: "License is required.")
    |> validate_required([:publishFrequency], message: "Publish Frequency is required.")
    |> validate_required([:orgTitle], message: "Organization is required.")
    |> validate_required([:private], message: "Level of Access is required.")
    |> validate_required([:sourceFormat], message: "Format is required.")
  end

  defp get_business(map) when is_map(map) do
    Map.take(map, Map.keys(@business_fields))
  end

  defp get_technical(map) when is_map(map) do
    Map.take(map, Map.keys(@technical_fields))
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
