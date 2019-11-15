defmodule AndiWeb.DatasetSchemaValidator do
  @moduledoc """
  Used to validate dataset schemas
  """

  def validate(%{"technical" => %{"sourceType" => source_type}}  = dataset) when source_type in ["ingest", "stream"] do
    validate_schema(dataset)
  end

  def validate(_), do: []

  def validate_schema(%{"technical" => %{"schema" => schema}}) when schema in [nil, []] do
    ["schema cannot be missing or empty"]
  end

  def validate_schema(%{"technical" => %{"sourceFormat" => "text/xml", "schema" => schema}}) do
    validate_schema_has_selectors(schema)
  end

  def validate_schema(_), do: []

  defp validate_schema_has_selectors(schema) do
    results =
      schema
      |> Enum.map(&build_field_validator/1)
      |> List.flatten()

    results
  end

  defp selector_required(item) do
    {&has_selector?/1, "a selector property is required for field: '#{get_name(item)}' in the schema", true}
  end

  defp get_name(%{"name" => name}), do: name

  defp has_selector?(schema_item) do
    case get_selector(schema_item) do
      nil -> false
      selector -> String.trim(selector) != ""
    end
  end

  defp get_selector(%{"selector" => selector}), do: selector
  defp get_selector(_), do: nil

  defp build_field_validator(%{"subSchema" => sub_schema} = field) do
    validate_schema_has_selectors(sub_schema) ++ SimplyValidate.validate(field, [selector_required(field)])
  end

  defp build_field_validator(field), do: SimplyValidate.validate(field, [selector_required(field)])
end
