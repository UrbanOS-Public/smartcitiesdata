defmodule Transformers.DateTime do
  @behaviour Transformation

  alias Transformers.FieldFetcher

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, [source_field, source_format, target_field, target_format]} <-
           validate(parameters),
         {:ok, payload_source_value} <- FieldFetcher.fetch_value(payload, source_field),
         {:ok, source_datetime} <-
           string_to_datetime(payload_source_value, source_format, source_field),
         {:ok, transformed_datetime} <- format_datetime(source_datetime, target_format) do
      {:ok, payload |> Map.put(target_field, transformed_datetime)}
    else
      {:error, reason} ->
        {:error, reason}

      nil_payload ->
        {:ok, nil_payload}
    end
  end

  def validate(parameters) do
    with {:ok, source_field} <- FieldFetcher.fetch_parameter(parameters, "sourceField"),
         {:ok, source_format} <- FieldFetcher.fetch_parameter(parameters, "sourceFormat"),
         {:ok, target_field} <- FieldFetcher.fetch_parameter(parameters, "targetField"),
         {:ok, target_format} <- FieldFetcher.fetch_parameter(parameters, "targetFormat"),
         :ok <- validate_datetime_format(source_format),
         :ok <- validate_datetime_format(target_format) do
      {:ok, [source_field, source_format, target_field, target_format]}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate_new(parameters) do
    ["sourceField", "sourceFormat", "targetField", "targetFormat"]
      |> Enum.reverse()
      |> check_for_missing_fields(parameters)
      |> check_for_incorrect_datetime_format(["sourceFormat", "targetFormat"], parameters)
      |> ordered_values_or_errors()
  end

  defp check_for_incorrect_datetime_format(accumulated, datetime_fields, parameters) do
    Enum.reduce(datetime_fields, accumulated, fn field, accumulator ->
      if field_has_no_prior_errors?(accumulator, field) do
        update_with_any_datetime_errors(accumulator, parameters, field)
      else
        accumulator
      end
    end)
  end

  defp field_has_no_prior_errors?(accumulator, field) do
    get_in(accumulator, [:errors, field]) == nil
  end

  defp update_with_any_datetime_errors(accumulator, parameters, field) do
    {:ok, value} = FieldFetcher.fetch_parameter(parameters, field)
    result = validate_datetime_format(value)
    case result do
      :ok -> accumulator
      {:error, reason} -> Map.update(accumulator, :errors, %{}, fn errors -> Map.put(errors, field, reason) end)
    end
  end

  defp check_for_missing_fields(required_fields, parameters) do
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

  defp string_to_datetime(date_string, date_format, source_field) do
    with {:ok, result} <- Timex.parse(date_string, date_format) do
      {:ok, result}
    else
      {:error, timexReason} ->
        {:error,
         "Unable to parse datetime from \"#{source_field}\" in format \"#{date_format}\": #{
           timexReason
         }"}
    end
  end

  defp validate_datetime_format(format) do
    with :ok <- Timex.Format.DateTime.Formatter.validate(format) do
      :ok
    else
      {:error, reason} ->
        {:error, "DateTime format \"#{format}\" is invalid: #{reason}"}
    end
  end

  defp format_datetime(dateTime, format) do
    with {:ok, result} <- Timex.format(dateTime, format) do
      {:ok, result}
    else
      {:error, {:format, reason}} ->
        {:error, "Unable to format datetime \"#{dateTime}\" in format \"#{format}\": #{reason}"}
    end
  end
end
