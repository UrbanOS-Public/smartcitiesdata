defmodule Transformers.DateTime do
  @behaviour Transformation

  alias Transformations.FieldFetcher

  @impl Transformation

  def transform(payload, parameters) do
    with {:ok, sourceField} <- FieldFetcher.fetch_parameter(parameters, :sourceField),
         {:ok, sourceFormat} <- FieldFetcher.fetch_parameter(parameters, :sourceFormat),
         {:ok, targetField} <- FieldFetcher.fetch_parameter(parameters, :targetField),
         {:ok, targetFormat} <- FieldFetcher.fetch_parameter(parameters, :targetFormat),
         {:ok, payloadSourceValue} <- FieldFetcher.fetch_value(payload, sourceField),
         {:ok, sourceDatetime} <- parseTime(payloadSourceValue, sourceFormat, sourceField),
         {:ok, transformedDatetime} <- formatDateTime(sourceDatetime, targetFormat) do
      {:ok, payload |> Map.put(targetField, transformedDatetime)}
    else
      {:error, reason} ->
        {:error, reason}

      nil_payload ->
        {:ok, nil_payload}
    end
  end

  defp parseTime(dateString, dateFormat, sourceField) do
    with {:ok, result} <- Timex.parse(dateString, dateFormat) do
      {:ok, result}
    else
      {:error, timexReason} ->
        {:error,
         "Unable to parse datetime from \"#{sourceField}\" in format \"#{dateFormat}\": #{
           timexReason
         }"}
    end
  end

  defp formatDateTime(dateTime, format) do
    with {:ok, result} <- Timex.format(dateTime, format) do
      {:ok, result}
    else
      {:error, {:format, reason}} ->
        {:error, "Unable to format datetime in format \"#{format}\": #{reason}"}
    end
  end
end
