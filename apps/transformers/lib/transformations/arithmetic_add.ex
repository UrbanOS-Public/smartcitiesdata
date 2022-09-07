defmodule Transformers.ArithmeticAdd do
  @behaviour Transformation

  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  @impl Transformation

  @addends "addends"
  @target_field "targetField"

  def transform(payload, parameters) do
    with {:ok, [addends, target_field]} <- validate(parameters),
         {:ok, value} <- sumValues(addends, payload) do
      modified_payload = Map.put(payload, target_field, value)
      {:ok, modified_payload}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp sumValues(addends, payload) do
    Enum.reduce_while(addends, {:ok, 0}, fn addend, {:ok, acc} ->
      result =
        cond do
          is_number(addend) -> addend
          true -> Map.get(payload, addend)
        end

      cond do
        is_number(result) -> {:cont, {:ok, acc + result}}
        is_nil(result) -> {:halt, {:error, "Missing field in payload: #{addend}"}}
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
