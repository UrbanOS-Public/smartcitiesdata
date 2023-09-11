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

  # used with condition input form. Can be "Static Value" or "Target Field" or "Null or Empty"
  @condition_compare_to "conditionCompareTo"

  def check(payload, parameters) do
    with true <- Map.has_key?(parameters, "condition"),
         "true" <- Map.get(parameters, "condition"),
         {:ok,
          [
            operation,
            source_field,
            target_field,
            target_value,
            source_format,
            target_format,
            data_type,
            compare_to
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
             data_type,
             compare_to
           ) do
      {:ok, result}
    else
      false -> {:ok, true}
      "false" -> {:ok, true}
      nil -> {:ok, true}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate(parameters) do
    valid_status =
      %ValidationStatus{}
      |> NotBlank.check(parameters, @condition_compare_to)
      |> NotBlank.check(parameters, @data_type)
      |> NotBlank.check(parameters, @operation_field)
      |> NotBlank.check(parameters, @source_field)
      |> NotBlank.check_nested(parameters, @source_field)

    comp_val = Map.get(parameters, @condition_compare_to)

    valid_status =
      case comp_val do
        "Static Value" ->
          valid_status
          |> NotBlank.check(parameters, @target_value)
          |> check_datetime(parameters)

        "Target Field" ->
          valid_status
          |> NotBlank.check(parameters, @target_field)
          |> NotBlank.check_nested(parameters, @target_field)
          |> check_datetime(parameters)

        _ ->
          valid_status
      end

    valid_status
    |> ValidationStatus.ordered_values_or_errors([
      @operation_field,
      @source_field,
      @target_field,
      @target_value,
      @source_date_format,
      @target_date_format,
      @data_type,
      @condition_compare_to
    ])
  end

  defp check_datetime(status, parameters) do
    type = Map.get(parameters, @data_type)
    type = if not is_nil(type), do: String.downcase(type)

    if type == "datetime" do
      NotBlank.check(status, parameters, @source_date_format)
      |> NotBlank.check(parameters, @target_date_format)
      |> DateTimeFormat.check(parameters, @source_date_format)
      |> DateTimeFormat.check(parameters, @target_date_format)
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
         data_type,
         compare_to
       ) do
    try do
      left_value = try_parse(Map.fetch!(payload, source_field), data_type, source_format)

      right_value =
        cond do
          compare_to == "Null or Empty" ->
            nil

          is_nil(target_value) ->
            try_parse(Map.fetch!(payload, target_field), data_type, target_format)

          true ->
            try_parse(target_value, data_type, target_format)
        end

      case map_operation(operation) do
        operation when compare_to == "Null or Empty" and operation == "=" ->
          {:ok, left_value in [nil, ""]}

        operation when compare_to == "Null or Empty" and operation == "!=" ->
          {:ok, left_value not in [nil, ""]}

        "=" ->
          {:ok, left_value == right_value}

        "!=" ->
          {:ok, left_value != right_value}

        ">" ->
          {:ok, left_value > right_value}

        "<" ->
          {:ok, left_value < right_value}

        _ ->
          {:error, "unsupported condition operation"}
      end
    rescue
      error -> {:error, error}
    end
  end

  defp try_parse(value, type, format) do
    case String.downcase(type) do
      _ when is_nil(value) ->
        value

      "string" ->
        if is_binary(value), do: value, else: Kernel.inspect(value)

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

  def map_operation(value) do
    case value do
      "Is Equal To" -> "="
      "Is Not Equal To" -> "!="
      "Is Greater Than" -> ">"
      "Is Less Than" -> "<"
      _ -> value
    end
  end
end
