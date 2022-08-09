defmodule Transformers.RegexExtract do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.RegexUtils

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, [source_field, target_field, regex]} <- validate_new(parameters),
         {:ok, value} <- FieldFetcher.fetch_value(payload, source_field) do
      case Regex.run(regex, value, capture: :all_but_first) do
        nil ->
          transformed_payload = Map.put(payload, target_field, nil)
          {:ok, transformed_payload}

        [extracted_value | _] ->
          transformed_payload = Map.put(payload, target_field, extracted_value)
          {:ok, transformed_payload}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate(parameters) do
    with {:ok, source_field} <- FieldFetcher.fetch_parameter(parameters, "sourceField"),
         {:ok, regex_pattern} <- FieldFetcher.fetch_parameter(parameters, "regex"),
         {:ok, target_field} <- FieldFetcher.fetch_parameter(parameters, "targetField"),
         {:ok, regex} <- RegexUtils.regex_compile(regex_pattern) do
      {:ok, [source_field, target_field, regex]}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_new(parameters) do
    reverse_fields_for_easier_list_updates_while_preserving_order()
      |> validate_fields(parameters)
      |> validate_regex(parameters)
      |> ordered_values_or_errors()
  end

  defp validate_regex(accumulator, parameters) do
    with {:ok, regex_pattern} <- FieldFetcher.fetch_parameter_new(parameters, "regex"),
         {:ok, regex} <- RegexUtils.regex_compile(regex_pattern) do
      Map.update(accumulator, :values, %{}, fn values -> Map.put(values, "regex", regex) end)
    else
      {:error, reason} -> Map.update(accumulator, :errors, %{}, fn errors -> Map.put(errors, "regex", reason) end)
    end
  end

  defp reverse_fields_for_easier_list_updates_while_preserving_order do
    ["sourceField", "targetField", "regex"] |> Enum.reverse()
  end

  defp validate_fields(required_fields, parameters) do
    Enum.reduce(required_fields, %{values: %{}, errors: %{}}, fn required_field, accumulator ->
      update_with_value_or_error(required_field, accumulator, parameters)
    end)
  end

  defp update_with_value_or_error(required_field, accumulator, parameters) do
    result = FieldFetcher.fetch_value_or_error(parameters, required_field)
    case result do
      {:ok, value} -> update_with_value(accumulator, required_field, value)
      {:error, reason} -> update_with_error(accumulator, reason)
    end
  end

  defp update_with_value(accumulator, field, value) do
    Map.update(accumulator, :values, %{}, fn values -> Map.put(values, field, value) end)
  end

  defp update_with_error(accumulator, error_reason) do
    Map.update(accumulator, :errors, %{}, fn errors -> Map.merge(errors, error_reason) end)
  end

  defp ordered_values_or_errors(accumulated) do
    errors = Map.get(accumulated, :errors)
    if length(Map.keys(errors)) > 0 do
      {:error, errors}
    else
      values = Map.get(accumulated, :values)
      source_field = Map.get(values, "sourceField")
      target_field = Map.get(values, "targetField")
      regex = Map.get(values, "regex")
      {:ok, [source_field, target_field, regex]}
    end
  end

end
