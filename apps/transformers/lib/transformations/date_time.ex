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
