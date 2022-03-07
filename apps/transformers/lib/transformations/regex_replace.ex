defmodule Transformers.RegexReplace do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.RegexUtils

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, source_field} <- FieldFetcher.fetch_parameter(parameters, "source_field"),
         {:ok, regex_pattern} <- FieldFetcher.fetch_parameter(parameters, "regex"),
         {:ok, replacement} <- FieldFetcher.fetch_parameter(parameters, "replacement"),
         {:ok, value} <- FieldFetcher.fetch_value(payload, source_field),
         {:ok, regex} <- RegexUtils.regex_compile(regex_pattern),
         :ok <- abort_if_not_string(replacement) do
           {:ok, payload}
    else
      {:error, reason} -> {:error, reason}
    end

  end

  defp abort_if_not_string(replacement) do
    if is_bitstring(replacement) do
      :ok
    else
      {:error, "Replacement value is not a string: #{replacement}"}
    end
  end

end
