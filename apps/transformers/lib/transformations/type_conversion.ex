defmodule Transformers.TypeConversion do
  @behaviour Transformation

  alias Transformers.FieldFetcher

  @impl Transformation
  def transform(payload, params) do
    with {:ok, [field, source_type, target_type, conversion_function]} <- validate(params),
         {:ok, value} <- FieldFetcher.fetch_value(payload, field),
         :ok <- abort_if_missing_value(payload, field, value),
         :ok <- check_field_is_of_sourcetype(field, value, source_type) do
      parse_or_error(conversion_function, payload, field, value, target_type)
    else
      {:error, reason} -> {:error, reason}
      nil_payload -> {:ok, nil_payload}
    end
  end

  def validate(params) do
    with {:ok, field} <- FieldFetcher.fetch_parameter(params, "field"),
         {:ok, source_type} <- FieldFetcher.fetch_parameter(params, "sourceType"),
         {:ok, target_type} <- FieldFetcher.fetch_parameter(params, "targetType"),
         {:ok, conversion_function} <- pick_conversion(source_type, target_type) do
      {:ok, [field, source_type, target_type, conversion_function]}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_new(parameters) do
    required_fields()
      |> validate_fields(parameters)
      |> validate_conversion(parameters)
      |> ordered_values_or_errors()
  end

  defp validate_conversion(accumulator, parameters) do
    prior_error_source_type = get_in(accumulator, [:errors, "sourceType"])
    prior_error_target_type = get_in(accumulator, [:errors, "targetType"])

    if prior_error_source_type != nil || prior_error_target_type != nil do
      accumulator
    else
      with {:ok, source_type} <- FieldFetcher.fetch_parameter(parameters, "sourceType"),
           {:ok, target_type} <- FieldFetcher.fetch_parameter(parameters, "targetType"),
           {:ok, conversion_function} <- pick_conversion(source_type, target_type) do
        Map.update(accumulator, :values, %{}, fn values -> Map.put(values, "conversionFunction", conversion_function) end)
      else
        {:error, reason} -> Map.update(accumulator, :errors, %{}, fn errors -> Map.put(errors, "sourceType", reason) end)
          |> Map.update(:errors, %{}, fn errors -> Map.put(errors, "targetType", reason) end)
      end
    end
  end

  defp required_fields() do
    ["field", "sourceType", "targetType"]
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
      field = Map.get(values, "field")
      sourceType = Map.get(values, "sourceType")
      targetType = Map.get(values, "targetType")
      conversion_function = Map.get(values, "conversionFunction")
      {:ok, [field, sourceType, targetType, conversion_function]}
    end
  end

  defp pick_conversion(source_type, target_type) do
    case {source_type, target_type} do
      {"float", "integer"} -> {:ok, fn value -> Float.round(value) end}
      {"float", "string"} -> {:ok, fn value -> to_string(value) end}
      {"integer", "float"} -> {:ok, fn value -> value / 1 end}
      {"integer", "string"} -> {:ok, fn value -> to_string(value) end}
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
    function =
      case source_type do
        "float" -> fn value -> is_float(value) end
        "integer" -> fn value -> is_integer(value) end
        "string" -> fn value -> is_binary(value) end
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
      transformed_payload = Map.put(payload, field, transformed_value)
      {:ok, transformed_payload}
    rescue
      _ -> {:error, "Cannot parse field #{field} with value #{value} into #{target_type}"}
    end
  end
end
