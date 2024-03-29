defmodule Transformers.FieldFetcher do
  def fetch_value_or_error(parameters, field) do
    result = fetch_parameter_new(parameters, field)

    case result do
      {:ok, value} -> {:ok, value}
      {:error, reason} -> {:error, %{field => reason}}
    end
  end

  def fetch_parameter(params, field_name) do
    fetch_or_error(params, field_name, "Missing transformation parameter: #{field_name}")
  end

  def fetch_parameter_new(params, field_name) do
    fetch_or_error(params, field_name, "Missing or empty field")
  end

  def fetch_value(payload, field_name) do
    fetch_or_error(payload, field_name, "Missing field in payload: #{field_name}")
  end

  defp fetch_or_error(map, field_name, error_msg) do
    case Map.fetch(map, field_name) do
      {:ok, field} -> {:ok, field}
      :error -> {:error, error_msg}
    end
  end
end
