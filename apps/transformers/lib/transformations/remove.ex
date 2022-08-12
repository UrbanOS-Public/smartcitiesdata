defmodule Transformers.Remove do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, source_field} <- validate_new(parameters),
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

  def validate_new(parameters) do
    result = %ValidationStatus{}
      |> NotBlank.check(parameters, "sourceField")

    if ValidationStatus.any_errors?(result) do
      {:error, result.errors}
    else
      ok_with_ordered_values(result)
    end
  end

  defp ok_with_ordered_values(status) do
    source_field = ValidationStatus.get_value(status, "sourceField")
    {:ok, source_field}
  end

  def fields() do
    [
      %{
        field_name: "sourceField",
        field_type: "string",
        field_label: "Field to Remove",
        options: nil
      }
    ]
  end
end
