defmodule Transformers.Remove do
  @behaviour Transformation

  alias Transformers.FieldFetcher

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, source_field} <- FieldFetcher.fetch_parameter(parameters, :sourceField) do
    else
      {:error, reason} -> {:error, reason}
    end
  end

end
