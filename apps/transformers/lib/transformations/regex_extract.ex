defmodule Transformers.RegexExtract do
  @behaviour Transformation

  @impl Transformation

  def transform(payload, parameters) do
    source_field = parameters.sourceField

    with {:ok, value} <- Map.fetch(payload, source_field),
         {:ok, regex} <- Regex.compile(parameters.regex) do
      case Regex.run(regex, value, capture: :all_but_first) do
        nil ->
          transformed_payload = Map.put(payload, parameters.targetField, nil)
          {:ok, transformed_payload}

        [extracted_value | _] ->
          transformed_payload = Map.put(payload, parameters.targetField, extracted_value)

          {:ok, transformed_payload}
      end
    else
      {:error, {message, index}} ->
        {:error, "Invalid regular expression: #{message} at index #{index}"}

      :error ->
        {:error, "Field #{source_field} not found"}
    end
  end
end
