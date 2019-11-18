defmodule AndiWeb.DatasetSchemaValidator do
  @moduledoc """
  Used to validate dataset schemas
  """

  def validate(%{"technical" => %{"sourceType" => source_type}} = dataset) when source_type in ["ingest", "stream"] do
    SimplyValidate.validate(dataset, [validate_schema_required()]) ++ validate_schema(dataset)
  end

  def validate(_), do: []

  def validate_schema(%{"technical" => %{"sourceFormat" => source_format, "schema" => schema}})
      when source_format in ["xml", "text/xml"] do
    validate_schema_has_selectors(schema)
  end

  def validate_schema(_), do: []

  defp validate_schema_required do
    {&has_schema?/1, "schema cannot be missing or empty", true}
  end

  defp has_schema?(%{"technical" => technical}) do
    case Map.get(technical, "schema") do
      nil -> false
      [] -> false
      _ -> true
    end
  end

  defp validate_schema_has_selectors(schema) do
    schema
    |> Enum.map(&build_field_validator/1)
    |> List.flatten()
  end

  defp selector_required(item) do
    {&has_selector?/1, "a selector property is required for field: '#{item["name"]}' in the schema", true}
  end

  defp has_selector?(schema_item) do
    case schema_item["selector"] do
      nil -> false
      selector -> String.trim(selector) != ""
    end
  end

  defp build_field_validator(%{"subSchema" => sub_schema} = field) do
    validate_schema_has_selectors(sub_schema) ++ SimplyValidate.validate(field, [selector_required(field)])
  end

  defp build_field_validator(field), do: SimplyValidate.validate(field, [selector_required(field)])
end
