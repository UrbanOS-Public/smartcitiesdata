defmodule Transformers.Division do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Decimal, as: D

  @dividend "dividend"
  @divisor "divisor"
  @target_field "targetField"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, [dividend, divisor, target_field_name]} <- validate(parameters),
         {:ok, dividend_product} <- resolve_payload_field(payload, dividend),
         {:ok, divisor_product} <- resolve_divisor(payload, divisor),
         {:ok, quotient} <- {:ok, D.div(D.new(dividend_product), D.new(divisor_product))} do
      {:ok, payload |> Map.put(target_field_name, quotient)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_divisor(payload, field) do
    case resolve_payload_field(payload, field) do
      {:ok, divisor} when divisor == 0 -> {:error, "divisor cannot be equal to 0"}
      any -> any
    end
  end

  defp resolve_payload_field(payload, field) do
    case field do
      constant when is_number(constant) ->
        {:ok, constant}

      payload_field ->
        case FieldFetcher.fetch_value(payload, payload_field) do
          {:ok, result} when not is_number(result) ->
            {:error, "payload field is not a number: #{payload_field}"}

          any ->
            any
        end
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check_nil(parameters, @dividend)
    |> NotBlank.check_nil(parameters, @divisor)
    |> NotBlank.check(parameters, @target_field)
    |> ValidationStatus.ordered_values_or_errors([@dividend, @divisor, @target_field])
  end

  def fields() do
    [
      %{
        field_name: "targetField",
        field_type: "string",
        field_label: "Field to populate with product",
        options: nil
      },
      %{
        field_name: "dividend",
        field_type: "string or number",
        field_label:
          "A field or number that will be used as the number being divided",
        options: nil
      },
      %{
        field_name: "divisor",
        field_type: "string or number",
        field_label:
          "A field or number that will be used as the number to divide by",
        options: nil
      }
    ]
  end
end
