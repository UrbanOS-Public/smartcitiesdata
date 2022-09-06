defmodule Transformers.ArithmeticAdd do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  @impl Transformation

  @addends "addends"
  @target_field "targetField"

  def transform(payload, parameters) do
    with {:ok, [addends, target_field]} <- validate(parameters) do
      value = Enum.sum(Enum.map(addends, fn addend -> Map.get(payload, addend, addend) end))
      modified_payload = Map.put(payload, target_field, value)
      {:ok, modified_payload}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @addends)
    |> NotBlank.check(parameters, @target_field)
    |> ValidationStatus.ordered_values_or_errors([@addends, @target_field])
  end
end

# Example -
# {
#   "type": "add",
#   "parameters": {
#     "addends": [1, "numberOfVehicles"],
#     "targetField": "numberOfVehicles"
#   }
# }
# Input Message
# {
#   "numberOfVehicles": 6
# }
# Output
# {
#   "numberOfVehicles": 7
# }
