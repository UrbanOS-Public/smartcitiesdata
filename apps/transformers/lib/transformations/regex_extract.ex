defmodule Transformers.RegexExtract do
  @behaviour Transformation

  alias Transformations.FieldFetcher

  @impl Transformation

  def transform(payload, parameters) do
    # TODO refactor to use fetch_parameter for this in with block
    source_field = parameters.sourceField

    with {:ok, value} <- FieldFetcher.fetch_value(payload, source_field),
         {:ok, regex} <- regex_compile(parameters.regex) do
      case Regex.run(regex, value, capture: :all_but_first) do
        nil ->
          transformed_payload = Map.put(payload, parameters.targetField, nil)
          {:ok, transformed_payload}

        [extracted_value | _] ->
          transformed_payload = Map.put(payload, parameters.targetField, extracted_value)
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
