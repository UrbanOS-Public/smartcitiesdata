defmodule Transformers.Remove do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Transformers.Conditions

  @source_field "sourceField"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, true} <- Conditions.check(payload, parameters),
         {:ok, [source_field]} <- validate(parameters),
         {:ok, _} <- FieldFetcher.fetch_value(payload, source_field) do
      transformed_payload = Map.delete(payload, source_field)
      {:ok, transformed_payload}
    else
      {:ok, false} -> {:ok, payload}
      {:error, reason} -> {:error, "Remove Transformation Error: #{inspect(reason)}"}
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @source_field)
    |> NotBlank.check_nested(parameters, @source_field)
    |> ValidationStatus.ordered_values_or_errors([@source_field])
  end

  def fields() do
    [
      %{
        field_name: @source_field,
        field_type: "string",
        field_label: "Field to Remove",
        options: nil
      }
    ]
  end
end
