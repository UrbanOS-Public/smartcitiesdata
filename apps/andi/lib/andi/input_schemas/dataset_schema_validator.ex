defmodule Andi.InputSchemas.DatasetSchemaValidator do
  @moduledoc """
  Used to validate dataset schemas
  """

  # todo: make a ticket to do this schema validation on ingestions if source_format is xml or text/xml
  # def validate(schema, source_format) when source_format in ["xml", "text/xml"] do
  #   validate_schema_has_selectors(schema)
  # end

  def validate(_, _), do: []

  # defp validate_schema_has_selectors(nil), do: []

  defp validate_schema_has_selectors(schema) do
    schema
    |> Enum.map(&build_field_validator/1)
    |> List.flatten()
  end

  defp selector_required(item) do
    {&has_selector?/1, "a selector property is required for field: '#{Map.get(item, :name)}' in the schema", true}
  end

  defp has_selector?(schema_item) do
    case Map.get(schema_item, :selector, nil) do
      nil -> false
      selector -> String.trim(selector) != ""
    end
  end

  defp build_field_validator(%{subSchema: sub_schema} = field) do
    validate_schema_has_selectors(sub_schema) ++ SimplyValidate.validate(field, [selector_required(field)])
  end

  defp build_field_validator(field), do: SimplyValidate.validate(field, [selector_required(field)])
end
