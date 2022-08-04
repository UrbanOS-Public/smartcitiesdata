defmodule Transformers.Remove do
  @behaviour Transformation

  alias Transformers.FieldFetcher

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, source_field} <- validate(parameters),
         {:ok, _} <- FieldFetcher.fetch_value(payload, source_field) do
      transformed_payload = Map.delete(payload, source_field)
      {:ok, transformed_payload}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate(parameters) do
    with {:ok, source_field} <- FieldFetcher.fetch_parameter(parameters, "sourceField") do
      {:ok, source_field}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def fields() do
    [%{
      field_name: "sourceField",
      field_type: "string",
      field_label: "Field to Remove",
      options: nil
    }]
  end
end
