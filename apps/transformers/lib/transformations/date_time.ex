defmodule Transformers.DateTime do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.DateTimeFormat
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  @source_field "sourceField"
  @source_format "sourceFormat"
  @target_field "targetField"
  @target_format "targetFormat"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, [source_field, source_format, target_field, target_format]} <-
           validate_parameters(parameters),
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

  @impl Transformation
  def validate_parameters(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @source_field)
    |> NotBlank.check(parameters, @source_format)
    |> NotBlank.check(parameters, @target_field)
    |> NotBlank.check(parameters, @target_format)
    |> DateTimeFormat.check(parameters, @source_format)
    |> DateTimeFormat.check(parameters, @target_format)
    |> ValidationStatus.ordered_values_or_errors([
      @source_field,
      @source_format,
      @target_field,
      @target_format
    ])
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
