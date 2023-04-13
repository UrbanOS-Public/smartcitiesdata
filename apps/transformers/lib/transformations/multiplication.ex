defmodule Transformers.Multiplication do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Transformers.ParseUtils
  alias Decimal, as: D
  alias Transformers.Conditions

  @multiplicands "multiplicands"
  @target_field "targetField"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, true} <- Conditions.check(payload, parameters),
         {:ok, [multiplicands, target_field_name]} <- validate(parameters),
         {:ok, numeric_multiplicands} <- ParseUtils.operandsToNumbers(multiplicands, payload),
         {:ok, resolved_multiplicands} <-
           resolve_multiplicand_fields(payload, numeric_multiplicands),
         product <- multiply_multiplicands(resolved_multiplicands) do
      {:ok, payload |> Map.put(target_field_name, D.to_float(product))}
    else
      {:ok, false} -> {:ok, payload}
      {:error, reason} -> {:error, reason}
    end
  end

  defp multiply_multiplicands(resolved_multiplicands) do
    Enum.reduce(resolved_multiplicands, 1, fn multiplicand, acc ->
      D.mult(D.cast(multiplicand), D.cast(acc))
    end)
  end

  defp resolve_multiplicand_fields(payload, multiplicands) do
    numbers =
      Enum.reduce_while(multiplicands, [], fn multiplicand, acc ->
        case resolve_multiplicand_field(payload, multiplicand) do
          {:ok, result} -> {:cont, acc ++ [result]}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case numbers do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, numbers}
    end
  end

  defp resolve_multiplicand_field(payload, multiplicand) do
    case multiplicand do
      constant when is_number(constant) ->
        {:ok, constant}

      payload_field ->
        case FieldFetcher.fetch_value(payload, payload_field) do
          {:ok, result} when not is_number(result) ->
            {:error, "multiplicand field not a number: #{payload_field}"}

          any ->
            any
        end
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @multiplicands)
    |> NotBlank.check(parameters, @target_field)
    |> NotBlank.check_nested(parameters, @multiplicands)
    |> NotBlank.check_nested(parameters, @target_field)
    |> ValidationStatus.ordered_values_or_errors([@multiplicands, @target_field])
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
        field_name: "multiplicands",
        field_type: "list",
        field_label: "List of values or fields to multiply together",
        options: nil
      }
    ]
  end
end
