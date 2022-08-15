defmodule Transformers.Concatenation do
  @behaviour Transformation

  alias Transformers.Validations.IsPresent
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  @source_fields "sourceFields"
  @target_field "targetField"
  @separator "separator"

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
    %ValidationStatus{}
      |> NotBlank.check(parameters, @source_fields)
      |> NotBlank.check(parameters, @target_field)
      |> IsPresent.check(parameters, @separator)
      |> ValidationStatus.ordered_values_or_errors([@source_fields, @separator, @target_field])
  end

  def fetch_values(payload, field_names) when is_list(field_names) do
    find_values_or_errors(payload, field_names)
    |> all_values_if_present_else_error()
  end

  def fetch_values(_, _), do: {:error, "Expected list but received single value: #{@source_fields}"}

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
