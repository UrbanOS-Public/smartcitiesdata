defmodule Transformers.TypeConversion do
  @behaviour Transformation

  @impl Transformation
  def transform(payload, params) do

    with {:ok, field} <- fetch_parameter(params, :field),
         {:ok, source_type} <- fetch_parameter(params, :sourceType),
         {:ok, value} <- fetch_payload_value(payload, field),
         :ok <- abort_if_missing_value(payload, field, value),
         :ok <- check_field_is_of_sourcetype(field, value, source_type) do

    else
      {:error, reason} -> {:error, reason}
      nil_payload -> nil_payload
    end

  end

  defp abort_if_missing_value(payload, field, value) do
    if(value == nil or value == "") do
      Map.put(payload, field, nil)
    else
      :ok
    end
  end

  defp fetch_parameter(params, field_name) do
    case Map.fetch(params, field_name) do
      {:ok, field} -> {:ok, field}
      :error -> {:error, "Missing transformation parameter: #{field_name}"}
    end
  end

  defp fetch_payload_value(payload, field_name) do
    case Map.fetch(payload, field_name) do
      {:ok, field} -> {:ok, field}
      :error -> {:error, "Missing field in payload: #{field_name}"}
    end
  end

  defp check_field_is_of_sourcetype(field, value, source_type) do
    function = case source_type do
      "float" -> fn value -> is_float(value) end
      # "integer" -> fn value -> is_integer(value) end
    end
    if function.(value) do
      :ok
    else
      {:error, "Field #{field} not of expected type: #{source_type}"}
    end
  end
end
