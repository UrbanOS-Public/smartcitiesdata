defmodule Transformers.Division do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Transformers.ParseUtils
  alias Decimal, as: D
  alias Transformers.Conditions

  @dividend "dividend"
  @divisor "divisor"
  @target_field "targetField"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, true} <- Conditions.check(payload, parameters),
         {:ok, [dividend, divisor, target_field_name]} <- validate(parameters),
         {:ok, numeric_dividend} <- ParseUtils.parseValue(dividend, payload),
         {:ok, numeric_divisor} <- ParseUtils.parseValue(divisor, payload),
         {:ok, _dividend} <- resolve_payload_field(payload, numeric_dividend),
         {:ok, _divisor} <- resolve_divisor(payload, numeric_divisor),
         {:ok, quotient} <- {:ok, D.div(D.cast(numeric_dividend), D.cast(numeric_divisor))} do
      {:ok, payload |> Map.put(target_field_name, D.to_float(quotient))}
    else
      {:ok, false} -> {:ok, payload}
      {:error, reason} -> {:error, "Division Transformation Error: #{inspect(reason)}"}
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
    |> NotBlank.check_nested(parameters, @dividend)
    |> NotBlank.check_nested(parameters, @divisor)
    |> NotBlank.check_nested(parameters, @target_field)
    |> ValidationStatus.ordered_values_or_errors([@dividend, @divisor, @target_field])
  end

  def fields() do
    [
      %{
        field_name: "targetField",
        field_type: "string",
        field_label: "Field to populate with quotient",
        options: nil
      },
      %{
        field_name: "dividend",
        field_type: "string or number",
        field_label: "A field or number that will be used as the number being divided",
        options: nil
      },
      %{
        field_name: "divisor",
        field_type: "string or number",
        field_label: "A field or number that will be used as the number to divide by",
        options: nil
      }
    ]
  end
end
