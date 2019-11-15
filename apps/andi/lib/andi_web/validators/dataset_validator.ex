defmodule AndiWeb.DatasetValidator do
  @moduledoc "Used to validate datasets"

  alias Andi.Services.DatasetRetrieval

  def validate(dataset) do
    result =
      SimplyValidate.validate(dataset, [
        validate_org_name(),
        validate_data_name(),
        validate_modified_date_format(),
        already_exists!(),
        description_required(),
        validate_top_level_selector_if_required()
      ]) ++
        validate_dataset_schema(dataset)

    case result do
      [] -> :valid
      errors -> {:invalid, errors}
    end
  end

  def validate_org_name do
    {&String.contains?(&1["technical"]["orgName"], "-"), "orgName cannot contain dashes", false}
  end

  def validate_data_name do
    {&String.contains?(&1["technical"]["dataName"], "-"), "dataName cannot contain dashes", false}
  end

  def validate_modified_date_format do
    {&check_valid_date(&1["business"]["modifiedDate"]),
     "modifiedDate must be iso8601 formatted, e.g. '2019-01-01T13:59:45'", true}
  end

  def already_exists! do
    {&check_already_exists/1, "Existing dataset has the same orgName and dataName", false}
  end

  defp check_already_exists(dataset) do
    existing_datasets = DatasetRetrieval.get_all!()

    Enum.any?(existing_datasets, fn existing_dataset ->
      different_ids(dataset, existing_dataset) &&
        same_system_name(dataset, existing_dataset)
    end)
  end

  def validate_top_level_selector_if_required() do
    {&has_top_level_selector_if_required/1, "topLevelSelector required for xml datasets", true}
  end

  defp has_top_level_selector_if_required(%{
         "technical" => %{"topLevelSelector" => topLevelSelector, "sourceFormat" => "text/xml"}
       }) do
    topLevelSelector != nil
  end

  defp has_top_level_selector_if_required(_), do: true

  defp same_system_name(a, b), do: get_system_name(a) == get_system_name(b)

  defp different_ids(a, b), do: get_id(a) != get_id(b)

  defp get_id(%{id: id}), do: id
  defp get_id(%{"id" => id}), do: id

  defp get_system_name(%{technical: technical}), do: technical.systemName
  defp get_system_name(%{"technical" => technical}), do: technical["systemName"]

  defp description_required do
    {&(&1["business"]["description"] != ""), "Description must be provided"}
  end

  defp check_valid_date(""), do: true

  defp check_valid_date(date) do
    case DateTime.from_iso8601(date) do
      {:ok, _date, _offset} ->
        true

      _ ->
        false
    end
  end

  defp validate_dataset_schema(%{"technical" => %{"schema" => schema, "sourceFormat" => "text/xml"}}) do
    validate_schema(schema)
  end

  defp validate_dataset_schema(_), do: []

  def validate_schema(schema) do
    results =
      schema
      |> Enum.map(&build_field_validator/1)
      |> List.flatten()

    results
  end

  defp selector_required(item) do
    {&has_selector?/1, "a selector property is required for field: '#{get_name(item)}' in the schema", true}
  end

  defp get_name(%{name: name}), do: name
  defp get_name(%{"name" => name}), do: name

  defp has_selector?(schema_item) do
    case get_selector(schema_item) do
      nil -> false
      selector -> String.trim(selector) != ""
    end
  end

  defp get_selector(%{selector: selector}), do: selector
  defp get_selector(%{"selector" => selector}), do: selector
  defp get_selector(_), do: nil

  defp build_field_validator(%{"type" => "map", "subSchema" => subSchema} = field) do
    validate_schema(subSchema) ++ SimplyValidate.validate(field, [selector_required(field)])
  end

  defp build_field_validator(field), do: SimplyValidate.validate(field, [selector_required(field)])
end
