defmodule Transformers.DateTime do
  @behaviour Transformation

  use Timex

  alias Transformers.FieldFetcher
  alias Transformers.Validations.DateTimeFormat
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Transformers.Conditions

  @source_field "sourceField"
  @source_format "sourceFormat"
  @target_field "targetField"
  @target_format "targetFormat"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, true} <- Conditions.check(payload, parameters),
         {:ok, [source_field, source_format, target_field, target_format]} <-
           validate(parameters),
         {:ok, payload_source_value} <- FieldFetcher.fetch_value(payload, source_field),
         {:ok, source_datetime} <-
           string_to_datetime("#{payload_source_value}", source_format, source_field),
         {:ok, transformed_datetime} <- format_datetime(source_datetime, target_format) do
      {:ok, payload |> Map.put(target_field, transformed_datetime)}
    else
      {:ok, false} ->
        {:ok, payload}

      {:error, reason} ->
        {:error, reason}

      nil_payload ->
        {:ok, nil_payload}
    end
  end

  def validate(parameters) do
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
    with {:ok, result} <- parse_format(date_string, date_format) do
      {:ok, result}
    else
      {:error, timexReason} ->
        {:error,
         "Unable to parse datetime from \"#{source_field}\" in format \"#{date_format}\": #{
           timexReason
         }"}
    end
  end

  defp parse_format(string, format) do
    if format == "{s-epoch}" do
      normalized_value = "#{string}"

      try do
        seconds =
          if String.contains?(normalized_value, ".") do
            trunc(String.to_float(normalized_value))
          else
            case Float.parse(normalized_value) do
              {value, _} ->
                trunc(value)

              :error ->
                raise "Could not parse given value: #{normalized_value} into a float"
            end
          end

        if String.length("#{seconds}") < 13 do
          {:ok, Timex.from_unix(seconds)}
        else
          {:ok, Timex.from_unix(seconds, :milliseconds)}
        end
      rescue
        err -> {:error, inspect(err)}
      end
    else
      Timex.parse(string, format)
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

  def fields() do
    [
      %{
        field_name: @source_field,
        field_type: "string",
        field_label: "Source Field",
        options: nil
      },
      %{
        field_name: @source_format,
        field_type: "string",
        field_label: "Source Field Format",
        options: nil
      },
      %{
        field_name: @target_field,
        field_type: "string",
        field_label: "Target Field",
        options: nil
      },
      %{
        field_name: @target_format,
        field_type: "string",
        field_label: "Target Field Format",
        options: nil
      }
    ]
  end
end
