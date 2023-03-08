defmodule Transformers.Conditions do
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  @source_field "sourceField" # left side operand
  @target_field "targetField" # right side operand
  @target_value "targetValue" # right side operand when static compare value provided
  @operation_field "operation" # field containing operator

  def check(payload, parameters) do
    if Map.has_key?(parameters, "condition") do
      with {:ok, [operation, source_field, target_field, target_value]} <- validate(parameters),
          {:ok, result} <- eval(operation, source_field, target_field, target_value, payload) do
            {:ok, result}
      else
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, true}
    end
  end

  defp validate(parameters) do
    condition_params = Map.get(parameters, "condition")

    if is_nil(Map.get(condition_params, @target_value)) do
      %ValidationStatus{}
      |> NotBlank.check(condition_params, @operation_field)
      |> NotBlank.check(condition_params, @source_field)
      |> NotBlank.check(condition_params, @target_field)
      |> ValidationStatus.ordered_values_or_errors([@operation_field, @source_field, @target_field, @target_value])
    else
      %ValidationStatus{}
      |> NotBlank.check(condition_params, @operation_field)
      |> NotBlank.check(condition_params, @source_field)
      |> NotBlank.check(condition_params, @target_value)
      |> ValidationStatus.ordered_values_or_errors([@operation_field, @source_field, @target_field, @target_value])
    end
  end

  defp eval(operation, source_field, target_field, target_value, payload) do
    try do
      left_value = Map.fetch!(payload, source_field)
      right_value = if is_nil(target_value), do: Map.fetch!(payload, target_field), else: target_value
      case operation do
        "=" -> {:ok, left_value == right_value}
        "!=" -> {:ok, left_value != right_value}
        ">" -> {:ok, try_parse(left_value) > try_parse(right_value)}
        "<" -> {:ok, try_parse(left_value) < try_parse(right_value)}
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
