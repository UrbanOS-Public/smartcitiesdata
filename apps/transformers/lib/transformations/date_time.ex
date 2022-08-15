defmodule Transformers.DateTime do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.DateTimeFormat
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

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
    %ValidationStatus{}
      |> NotBlank.check(parameters, "sourceField")
      |> NotBlank.check(parameters, "sourceFormat")
      |> NotBlank.check(parameters, "targetField")
      |> NotBlank.check(parameters, "targetFormat")
      |> DateTimeFormat.check(parameters, "sourceFormat")
      |> DateTimeFormat.check(parameters, "targetFormat")
      |> ordered_values_or_errors()
  end

  defp ordered_values_or_errors(status) do
    if ValidationStatus.any_errors?(status) do
      {:error, status.errors}
    else
      ok_with_ordered_values(status)
    end
  end

  defp ok_with_ordered_values(status) do
    source_field = ValidationStatus.get_value(status, "sourceField")
    source_format = ValidationStatus.get_value(status, "sourceFormat")
    target_field = ValidationStatus.get_value(status, "targetField")
    target_format = ValidationStatus.get_value(status, "targetFormat")
    {:ok, [source_field, source_format, target_field, target_format]}
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

  defp format_datetime(dateTime, format) do
    with {:ok, result} <- Timex.format(dateTime, format) do
      {:ok, result}
    else
      {:error, {:format, reason}} ->
        {:error, "Unable to format datetime \"#{dateTime}\" in format \"#{format}\": #{reason}"}
    end
  end
end
