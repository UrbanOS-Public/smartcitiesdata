defmodule Transformers.TypeConversion do
  @behaviour Transformation

  @impl Transformation
  def transform(payload, params) do

    with {:ok, field} <- fetch_parameter(params, :field),
         {:ok, source_type} <- fetch_parameter(params, :sourceType),
         {:ok, target_type} <- fetch_parameter(params, :targetType),
         {:ok, value} <- fetch_value(payload, field),
         {:ok, conversion_function} <- pick_conversion(source_type, target_type),
         :ok <- abort_if_missing_value(payload, field, value),
         :ok <- check_field_is_of_sourcetype(field, value, source_type) do
           parse_or_error(conversion_function, payload, field, value, target_type)
    else
      {:error, reason} -> {:error, reason}
      nil_payload -> nil_payload
    end

  end

  defp fetch_parameter(params, field_name) do
    case Map.fetch(params, field_name) do
      {:ok, field} -> {:ok, field}
      :error -> {:error, "Missing transformation parameter: #{field_name}"}
    end
  end

  defp fetch_value(payload, field_name) do
    case Map.fetch(payload, field_name) do
      {:ok, field} -> {:ok, field}
      :error -> {:error, "Missing field in payload: #{field_name}"}
    end
  end

  defp pick_conversion(source_type, target_type) do
    case {source_type, target_type} do
      {"integer", "float"} -> {:ok, fn value -> value / 1 end}
      {"integer", "string"} -> {:ok, fn value -> to_string(value) end}
      {"float", "integer"} -> {:ok, fn value -> Float.round(value) end}
      {"float", "string"} -> {:ok, fn value -> to_string(value) end}
      {"string", "integer"} -> {:ok, fn value -> String.to_integer(value) end}
      {"string", "float"} -> {:ok, fn value -> String.to_float(value) end}
      _ -> {:error, "Conversion from #{source_type} to #{target_type} is not supported"}
    end
  end

  defp abort_if_missing_value(payload, field, value) do
    if(value == nil or value == "") do
      Map.put(payload, field, nil)
    else
      :ok
    end
  end

  defp check_field_is_of_sourcetype(field, value, source_type) do
    function = case source_type do
      "float" -> fn value -> is_float(value) end
      "integer" -> fn value -> is_integer(value) end
      "string" -> fn value -> is_bitstring(value) end
    end
    if function.(value) do
      :ok
    else
      {:error, "Field #{field} not of expected type: #{source_type}"}
    end
  end
  
  defp parse_or_error(conversion_function, payload, field, value, target_type) do
    try do
      transformed_value = conversion_function.(value)
      Map.put(payload, field, transformed_value)
    rescue
      _ -> {:error, "Cannot parse field #{field} with value #{value} into #{target_type}"}
    end
  end


end
