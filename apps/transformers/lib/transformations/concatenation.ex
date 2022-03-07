defmodule Transformers.Concatenation do
  @behaviour Transformation

  alias Transformers.FieldFetcher

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, source_fields} <- FieldFetcher.fetch_parameter(parameters, "sourceFields"),
         {:ok, separator} <- FieldFetcher.fetch_parameter(parameters, "separator"),
         {:ok, target_field} <- FieldFetcher.fetch_parameter(parameters, "targetField") do
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
