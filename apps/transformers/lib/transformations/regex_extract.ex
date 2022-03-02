defmodule Transformers.RegexExtract do
  @behaviour Transformation

  alias Transformations.FieldFetcher

  @impl Transformation

  def transform(payload, parameters) do
    with {:ok, source_field} <- FieldFetcher.fetch_parameter(parameters, :sourceField),
         {:ok, regex_pattern} <- FieldFetcher.fetch_parameter(parameters, :regex),
         {:ok, target_field} <- FieldFetcher.fetch_parameter(parameters, :targetField),
         {:ok, value} <- FieldFetcher.fetch_value(payload, source_field),
         {:ok, regex} <- regex_compile(regex_pattern) do
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

  defp regex_compile(regex) do
    case Regex.compile(regex) do
      {:ok, regex} ->
        {:ok, regex}

      {:error, {message, index}} ->
        {:error, "Invalid regular expression: #{message} at index #{index}"}
    end
  end
end
