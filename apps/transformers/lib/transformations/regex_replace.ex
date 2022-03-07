defmodule Transformers.RegexReplace do
  @behaviour Transformation

  alias Transformers.FieldFetcher

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, source_field} <- FieldFetcher.fetch_parameter(parameters, "source_field"),
         {:ok, regex} <- FieldFetcher.fetch_parameter(parameters, "regex"),
         {:ok, replacement} <- FieldFetcher.fetch_parameter(parameters, "replacement"),
         {:ok, value} <- FieldFetcher.fetch_value(payload, source_field) do

    else
      {:error, reason} -> {:error, reason}
    end

  end

end
