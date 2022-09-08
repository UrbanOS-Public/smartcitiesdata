defmodule Transformers.Division do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Decimal, as: D

  @dividends "dividends"
  @divisors "divisors"
  @target_field "targetField"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, [dividends, divisors, target_field_name]} <- validate(parameters),
         {:ok, dividend_product} <- resolve_product(payload, dividends),
         {:ok, divisor_product} <- resolve_product(payload, divisors),
         {:ok, quotient} <- {:ok, D.div(D.new(dividend_product), D.new(divisor_product))} do
      {:ok, payload |> Map.put(target_field_name, quotient)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_product(payload, value_list) do
    product =
      Enum.reduce_while(value_list, 1, fn value, acc ->
        case resolve_payload_field(payload, value) do
          {:ok, result} -> {:cont, acc * result}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case product do
      {:error, reason} -> {:error, reason}
      _ -> {:ok, product}
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
    |> NotBlank.check(parameters, @dividends)
    |> NotBlank.check(parameters, @divisors)
    |> NotBlank.check(parameters, @target_field)
    |> ValidationStatus.ordered_values_or_errors([@dividends, @divisors, @target_field])
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
        field_name: "dividends",
        field_type: "list",
        field_label:
          "List of values or fields, multiplied together, that will be used as the number being divided",
        options: nil
      },
      %{
        field_name: "divisors",
        field_type: "list",
        field_label:
          "List of values or fields, multiplied together, that will be used as the number to divide by",
        options: nil
      }
    ]
  end
end
