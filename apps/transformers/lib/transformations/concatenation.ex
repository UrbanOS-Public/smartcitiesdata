defmodule Transformers.Concatenation do
  @behaviour Transformation

  alias Transformers.FieldFetcher

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, source_fields} <- FieldFetcher.fetch_parameter(parameters, "sourceFields"),
         {:ok, separator} <- FieldFetcher.fetch_parameter(parameters, "separator"),
         {:ok, target_field} <- FieldFetcher.fetch_parameter(parameters, "targetField"),
         {:ok, values} <- fetch_values(payload, source_fields) do
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_values(payload, field_names) when is_list(field_names) do
    results =
      Enum.reduce(field_names, %{values: [], errors: []}, fn field_name, accumulator ->
        case Map.fetch(payload, field_name) do
          {:ok, value} -> update_list_in_map(accumulator, :values, value)
          :error -> update_list_in_map(accumulator, :errors, field_name)
        end
      end)
    if length(Map.get(results, :errors)) == 0 do
      {:ok, Map.get(results, :values)}
    else
      errors = pretty_print_errors(results)
      {:error, "Missing field in payload: #{errors}"}
    end
  end

  def update_list_in_map(map, key, value) do
    Map.update(map, key, [], fn current -> [value | current] end)
  end

  def pretty_print_errors(results) do
    errors = Map.get(results, :errors)
      |> Enum.reverse()
      |> Enum.map(&to_string/1)
      |> Enum.join(", ")
    "[#{errors}]"
  end
end
