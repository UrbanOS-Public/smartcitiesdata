defmodule Transformers.Concatenation do
  @behaviour Transformation

  alias Transformers.FieldFetcher

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, [source_fields, separator, target_field]} <- validate(parameters),
         {:ok, values} <- fetch_values(payload, source_fields),
         :ok <- can_convert_to_string?(values) do
      joined_string = Enum.join(values, separator)
      transformed = Map.put(payload, target_field, joined_string)
      {:ok, transformed}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate(parameters) do
    with {:ok, source_fields} <- FieldFetcher.fetch_parameter(parameters, "sourceFields"),
         {:ok, separator} <- FieldFetcher.fetch_parameter(parameters, "separator"),
         {:ok, target_field} <- FieldFetcher.fetch_parameter(parameters, "targetField") do
      {:ok, [source_fields, separator, target_field]}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_new(parameters) do
    reverse_fields_for_easier_list_updates_while_preserving_order()
      |> validate_fields(parameters)
      |> ordered_values_or_errors()
  end

  defp reverse_fields_for_easier_list_updates_while_preserving_order do
    ["sourceFields", "separator", "targetField"] |> Enum.reverse()
  end

  defp validate_fields(required_fields, parameters) do
    Enum.reduce(required_fields, %{values: [], errors: %{}}, fn required_field, accumulator ->
      update_with_value_or_error(required_field, accumulator, parameters)
    end)
  end

  defp update_with_value_or_error(required_field, accumulator, parameters) do
    result = FieldFetcher.fetch_value_or_error(parameters, required_field)
    case result do
      {:ok, value} -> update_with_value(accumulator, value)
      {:error, reason} -> update_with_error(accumulator, reason)
    end
  end

  defp update_with_value(accumulator, value) do
    Map.update(accumulator, :values, [], fn values -> [value | values] end)
  end

  defp update_with_error(accumulator, error_reason) do
    Map.update(accumulator, :errors, %{}, fn errors -> Map.merge(errors, error_reason) end)
  end

  defp ordered_values_or_errors(accumulated) do
    errors = Map.get(accumulated, :errors)
    if length(Map.keys(errors)) > 0 do
      {:error, errors}
    else
      {:ok, Map.get(accumulated, :values)}
    end
  end

  def fetch_values(payload, field_names) when is_list(field_names) do
    find_values_or_errors(payload, field_names)
    |> all_values_if_present_else_error()
  end

  def fetch_values(_, _), do: {:error, "Expected list but received single value: sourceFields"}

  def find_values_or_errors(payload, field_names) do
    Enum.reduce(field_names, %{values: [], errors: []}, fn field_name, accumulator ->
      case Map.fetch(payload, field_name) do
        {:ok, value} -> update_list_in_map(accumulator, :values, value)
        :error -> update_list_in_map(accumulator, :errors, field_name)
      end
    end)
    |> reverse_list(:values)
    |> reverse_list(:errors)
  end

  def update_list_in_map(map, key, value) do
    Map.update(map, key, [], fn current -> [value | current] end)
  end

  def reverse_list(map, key) do
    Map.update(map, key, [], fn current -> Enum.reverse(current) end)
  end

  def all_values_if_present_else_error(results) do
    if length(Map.get(results, :errors)) == 0 do
      {:ok, Map.get(results, :values)}
    else
      errors = pretty_print_errors(results)
      {:error, "Missing field in payload: #{errors}"}
    end
  end

  def pretty_print_errors(results) do
    errors =
      Map.get(results, :errors)
      |> Enum.map(&to_string/1)
      |> Enum.join(", ")

    "[#{errors}]"
  end

  def can_convert_to_string?(values) do
    try do
      Enum.each(values, fn value -> to_string(value) end)
      :ok
    rescue
      _ -> {:error, "Could not convert all source fields into strings"}
    end
  end
end
