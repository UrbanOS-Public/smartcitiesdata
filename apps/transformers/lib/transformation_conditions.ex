defmodule Transformers.Conditions do
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  # left side operand
  @source_field "sourceConditionField"
  # right side operand
  @target_field "targetConditionField"
  # right side operand when static compare value provided
  @target_value "targetConditionValue"
  # field containing operator
  @operation_field "conditionOperation"

  def check(payload, parameters) do
    with true <- Map.has_key?(parameters, "condition"),
         {:ok, [operation, source_field, target_field, target_value]} <- validate(parameters),
         {:ok, result} <- eval(operation, source_field, target_field, target_value, payload) do
      {:ok, result}
    else
      false -> {:ok, true}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate(parameters) do
    condition_params = Map.get(parameters, "condition")

    if is_nil(Map.get(condition_params, @target_value)) do
      %ValidationStatus{}
      |> NotBlank.check(condition_params, @operation_field)
      |> NotBlank.check(condition_params, @source_field)
      |> NotBlank.check(condition_params, @target_field)
      |> ValidationStatus.ordered_values_or_errors([
        @operation_field,
        @source_field,
        @target_field,
        @target_value
      ])
    else
      %ValidationStatus{}
      |> NotBlank.check(condition_params, @operation_field)
      |> NotBlank.check(condition_params, @source_field)
      |> NotBlank.check(condition_params, @target_value)
      |> ValidationStatus.ordered_values_or_errors([
        @operation_field,
        @source_field,
        @target_field,
        @target_value
      ])
    end
  end

  defp eval(operation, source_field, target_field, target_value, payload) do
    try do
      left_value = try_parse(Map.fetch!(payload, source_field))

      right_value =
        if is_nil(target_value),
          do: try_parse(Map.fetch!(payload, target_field)),
          else: try_parse(target_value)

      case operation do
        "=" -> {:ok, left_value == right_value}
        "!=" -> {:ok, left_value != right_value}
        ">" -> {:ok, left_value > right_value}
        "<" -> {:ok, left_value < right_value}
        _ -> {:error, "unsupported condition operation"}
      end
    rescue
      error -> {:error, error}
    end
  end

  defp try_parse(value) do
    try do
      {val, _} = Float.parse(value)
      val
    rescue
      _ -> value
    end
  end
end
