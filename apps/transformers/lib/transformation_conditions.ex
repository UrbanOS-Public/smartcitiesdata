defmodule Transformers.Conditions do
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Transformers.Validations.DateTimeFormat

  # left side operand
  @source_field "sourceConditionField"

  # right side operand
  @target_field "targetConditionField"

  # right side operand when static compare value provided
  @target_value "targetConditionValue"

  # field containing operator
  @operation_field "conditionOperation"

  # data type of comparators
  # valid values: string, number (all numbers converted to float), datetime
  @data_type "conditionDataType"

  # used for datetime comparisons
  @source_date_format "conditionSourceDateFormat"
  @target_date_format "conditionTargetDateFormat"

  def check(payload, parameters) do
    with true <- Map.has_key?(parameters, "condition"),
         {:ok,
          [
            operation,
            source_field,
            target_field,
            target_value,
            source_format,
            target_format,
            data_type
          ]} <- validate(parameters),
         {:ok, result} <-
           eval(
             operation,
             source_field,
             target_field,
             target_value,
             payload,
             source_format,
             target_format,
             data_type
           ) do
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
      |> NotBlank.check(condition_params, @data_type)
      |> check_datetime(condition_params)
      |> NotBlank.check(condition_params, @operation_field)
      |> NotBlank.check(condition_params, @source_field)
      |> NotBlank.check(condition_params, @target_field)
      |> ValidationStatus.ordered_values_or_errors([
        @operation_field,
        @source_field,
        @target_field,
        @target_value,
        @source_date_format,
        @target_date_format,
        @data_type
      ])
    else
      %ValidationStatus{}
      |> NotBlank.check(condition_params, @data_type)
      |> check_datetime(condition_params)
      |> NotBlank.check(condition_params, @operation_field)
      |> NotBlank.check(condition_params, @source_field)
      |> NotBlank.check(condition_params, @target_value)
      |> ValidationStatus.ordered_values_or_errors([
        @operation_field,
        @source_field,
        @target_field,
        @target_value,
        @source_date_format,
        @target_date_format,
        @data_type
      ])
    end
  end

  defp check_datetime(status, condition_params) do
    if Map.get(condition_params, @data_type) == "datetime" do
      NotBlank.check(status, condition_params, @source_date_format)
      |> NotBlank.check(condition_params, @target_date_format)
      |> DateTimeFormat.check(condition_params, @source_date_format)
      |> DateTimeFormat.check(condition_params, @target_date_format)
    else
      status
    end
  end

  defp eval(
         operation,
         source_field,
         target_field,
         target_value,
         payload,
         source_format,
         target_format,
         data_type
       ) do
    try do
      left_value = try_parse(Map.fetch!(payload, source_field), data_type, source_format)

      right_value =
        if is_nil(target_value),
          do: try_parse(Map.fetch!(payload, target_field), data_type, target_format),
          else: try_parse(target_value, data_type, target_format)

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

  defp try_parse(value, type, format) do
    case type do
      "string" ->
        value

      "number" ->
        if not is_number(value) do
          {val, _} = Float.parse(value)
          val
        else
          value
        end

      "datetime" ->
        Timex.parse(value, format)

      _ ->
        raise "unsupported parse type"
    end
  end
end
