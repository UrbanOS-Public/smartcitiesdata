defmodule Transformers.Add do
  @behaviour Transformation

  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Transformers.ParseUtils
  alias Transformers.Conditions

  @addends "addends"
  @target_field "targetField"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, true} <- Conditions.check(payload, parameters),
         {:ok, [addends, target_field]} <- validate(parameters),
         {:ok, numeric_addends} <- ParseUtils.operandsToNumbers(addends, payload),
         {:ok, sum} <- sumValues(numeric_addends) do
      {:ok, payload |> Map.put(target_field, sum)}
    else
      {:ok, false} -> {:ok, payload}
      {:error, reason} -> {:error, reason}
    end
  end

  defp sumValues(addends) do
    Enum.reduce_while(addends, {:ok, 0}, fn addend, {:ok, acc} ->
      if is_number(addend) do
        {:cont, {:ok, acc + addend}}
      else
        {:halt, {:error, "A value is not a number: #{addend}"}}
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
        field_name: "addends",
        field_type: "list",
        field_label: "List of values or fields to add together",
        options: nil
      }
    ]
  end
end
