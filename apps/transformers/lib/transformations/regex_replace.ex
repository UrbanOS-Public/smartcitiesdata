defmodule Transformers.RegexReplace do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.RegexUtils

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, source_field} <- FieldFetcher.fetch_parameter(parameters, "sourceField"),
         {:ok, regex_pattern} <- FieldFetcher.fetch_parameter(parameters, "regex"),
         {:ok, replacement} <- FieldFetcher.fetch_parameter(parameters, "replacement"),
         {:ok, value} <- FieldFetcher.fetch_value(payload, source_field),
         {:ok, regex} <- RegexUtils.regex_compile(regex_pattern),
         :ok <- abort_if_not_string(value, source_field),
         :ok <- abort_if_not_string(replacement, "replacement") do
      transformed_value = Regex.replace(regex, value, replacement)
      transformed_payload = Map.put(payload, source_field, transformed_value)
      {:ok, transformed_payload}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp abort_if_not_string(value, field_name) do
    if is_binary(value) do
      :ok
    else
      {:error, "Value of field #{field_name} is not a string: #{value}"}
    end
  end
end
