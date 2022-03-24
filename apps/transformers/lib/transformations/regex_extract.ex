defmodule Transformers.RegexExtract do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.RegexUtils

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, [source_field, target_field, regex]} <- validate(parameters),
         {:ok, value} <- FieldFetcher.fetch_value(payload, source_field) do
      case Regex.run(regex, value, capture: :all_but_first) do
        nil ->
          transformed_payload = Map.put(payload, target_field, nil)
          {:ok, transformed_payload}

        [extracted_value | _] ->
          transformed_payload = Map.put(payload, target_field, extracted_value)
          {:ok, transformed_payload}
      end
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate(parameters) do
    with {:ok, source_field} <- FieldFetcher.fetch_parameter(parameters, "sourceField"),
         {:ok, regex_pattern} <- FieldFetcher.fetch_parameter(parameters, "regex"),
         {:ok, target_field} <- FieldFetcher.fetch_parameter(parameters, "targetField"),
         {:ok, regex} <- RegexUtils.regex_compile(regex_pattern) do
      {:ok, [source_field, target_field, regex]}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
