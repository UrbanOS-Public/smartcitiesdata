defmodule Transformers.Subtract do
  @behaviour Transformation

  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Transformers.ParseUtils
  alias Transformers.Conditions

  @minuend "minuend"
  @subtrahends "subtrahends"
  @target_field "targetField"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, true} <- Conditions.check(payload, parameters),
         {:ok, [minuend, subtrahends, target_field]} <- validate(parameters),
         {:ok, numeric_subtrahends} <- ParseUtils.operandsToNumbers(subtrahends, payload),
         {:ok, difference} <- subtractValues(minuend, numeric_subtrahends, payload) do
      {:ok, payload |> Map.put(target_field, difference)}
    else
      {:ok, false} -> {:ok, payload}
      {:error, reason} -> {:error, "Subtraction Transformation Error: #{inspect(reason)}"}
    end
  end

  defp subtractValues(minuend, subtrahends, payload) do
    minuendValue = Map.get(payload, minuend, minuend)

    if is_number(minuendValue) do
      Enum.reduce_while(subtrahends, {:ok, minuendValue}, fn subtrahend, {:ok, acc} ->
        payloadValue = Map.get(payload, subtrahend)

        cond do
          is_number(subtrahend) -> {:cont, {:ok, acc - subtrahend}}
          is_number(payloadValue) -> {:cont, {:ok, acc - payloadValue}}
          is_nil(payloadValue) -> {:halt, {:error, "Missing field in payload: #{subtrahend}"}}
          true -> {:halt, {:error, "A value is not a number: #{subtrahend}"}}
        end
      end)
    else
      {:error, "Missing field in payload: #{minuend}"}
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check_nil(parameters, @minuend)
    |> NotBlank.check(parameters, @target_field)
    |> NotBlank.check(parameters, @subtrahends)
    |> NotBlank.check_nested(parameters, @minuend)
    |> NotBlank.check_nested(parameters, @target_field)
    |> NotBlank.check_nested(parameters, @subtrahends)
    |> ValidationStatus.ordered_values_or_errors([@minuend, @subtrahends, @target_field])
  end

  def fields() do
    [
      %{
        field_name: "targetField",
        field_type: "string",
        field_label: "Field to populate with difference",
        options: nil
      },
      %{
        field_name: "subtrahends",
        field_type: "list",
        field_label: "List of values or fields to subtract from minuend",
        options: nil
      },
      %{
        field_name: "minuend",
        field_type: "string",
        field_label: "Field to subtract from",
        options: nil
      }
    ]
  end
end
