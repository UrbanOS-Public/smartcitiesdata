defmodule Transformers.Concatenation do
  @behaviour Transformation

  alias Transformers.FieldFetcher

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, source_fields} <- FieldFetcher.fetch_parameter(parameters, "sourceFields"),
         {:ok, separator} <- FieldFetcher.fetch_parameter(parameters, "separator"),
         {:ok, target_field} <- FieldFetcher.fetch_parameter(parameters, "targetField") do
         # {:ok, values} <- fetch_values(payload, source_fields) do
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def fetch_values(payload, field_names) when is_list(field_names) do
    errors = []
    values = []
    IO.inspect(errors, label: "errors")
    IO.inspect(values, label: "values")
    Enum.each(field_names, fn field_name ->
      IO.inspect(field_name, label: "field name")
      IO.inspect(Map.fetch(payload, field_name), label: "fetch")
      case Map.fetch(payload, field_name) do
        {:ok, value} -> values ++ [value]
        :error -> errors ++ [field_name]
      end
      IO.inspect(errors, label: "errors")
      IO.inspect(values, label: "values")
    end)
    IO.inspect(errors, label: "errors")
    IO.inspect(values, label: "values")
    if(length(errors) == 0) do
      {:ok, values}
    else
      {:error, "Missing field in payload: #{errors}"}
    end
  end
end
