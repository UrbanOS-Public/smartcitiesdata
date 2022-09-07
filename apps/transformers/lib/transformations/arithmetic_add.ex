defmodule Transformers.ArithmeticAdd do
  @behaviour Transformation

  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  @addends "addends"
  @target_field "targetField"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, [addends, target_field]} <- validate(parameters),
         {:ok, sum} <- sumValues(addends, payload) do
         {:ok, payload |> Map.put(target_field, sum)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp sumValues(addends, payload) do
    Enum.reduce_while(addends, {:ok, 0}, fn addend, {:ok, acc} ->
      payloadValue = Map.get(payload, addend)
      cond do
        is_number(addend) -> {:cont, {:ok, acc + addend}}
        is_number(payloadValue) -> {:cont, {:ok, acc + payloadValue}}
        is_nil(payloadValue) -> {:halt, {:error, "Missing field in payload: #{addend}"}}
        true -> {:halt, {:error, "A value is not a number: #{addend}"}}
      end
    end)
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @addends)
    |> NotBlank.check(parameters, @target_field)
    |> ValidationStatus.ordered_values_or_errors([@addends, @target_field])
  end

  def fields() do
    [
      %{
        field_name: "targetField",
        field_type: "string",
        field_label: "Field to populate with sum",
        options: nil
      },
      %{
        field_name: "targetField",
        field_type: "list",
        field_label: "List of values or fields to add to targetField",
        options: nil
      }
    ]
  end
end
