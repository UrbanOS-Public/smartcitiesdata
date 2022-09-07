defmodule Transformers.Multiplication do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  @multiplicands "multiplicands"
  @target_field "targetField"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, [multiplicands, target_field_name]} <- validate_parameters(parameters),
         {:ok, resolved_multiplicands} <- resolve_multiplicand_fields(payload, multiplicands) do
      {:ok,
       payload
       |> Map.put(
         target_field_name,
         Enum.reduce(resolved_multiplicands, 1, fn multiplicand, acc -> multiplicand * acc end)
       )}
    else
      {:error, reason} -> {:error, reason}
    end
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

  def validate_parameters(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @multiplicands)
    |> NotBlank.check(parameters, @target_field)
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
