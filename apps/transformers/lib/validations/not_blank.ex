defmodule Transformers.Validations.NotBlank do
  alias Transformers.Validations.ValidationStatus

  def check(status, parameters, field) do
    if ValidationStatus.has_error?(status, field) do
      status
    else
      check_if_blank(status, parameters, field)
    end
  end

  def check_nil(status, parameters, field) do
    value = Map.get(parameters, field)

    case value do
      "" -> ValidationStatus.add_error(status, field, "Missing or empty field")
      nil -> ValidationStatus.add_error(status, field, "Missing or empty field")
      _ -> ValidationStatus.update_value(status, field, value)
    end
  end

  def check_nested(status, parameters, field) do
    if ValidationStatus.has_error?(status, field) do
      status
    else
      value = Map.get(parameters, field)

      invalid? = case value do
        nil -> ValidationStatus.add_error(status, field, "Missing or empty field")
        value when is_binary(value) -> check_if_nested_binary_invalid(value)
        value when is_list(value) -> check_if_nested_list_invalid(value)
        value when is_number(value) -> false
        _ -> true
      end

      case invalid? do
        true -> ValidationStatus.add_error(status, field, "Missing or empty child field")
        false -> ValidationStatus.update_value(status, field, value)
      end
    end
  end

  defp check_if_nested_binary_invalid(value) do
    case String.split(value, ", ") do
      split when length(split) == 1 ->
        String.ends_with?(value, ".")
      split ->
        check_if_nested_list_invalid(split)
    end
  end

  defp check_if_nested_list_invalid(values) do
    Enum.any?(values, fn
      value when is_binary(value) -> String.ends_with?(value, ".")
      value when is_number(value) -> false
      _value -> true
    end)
  end

  defp check_if_blank(status, parameters, field) do
    value = Map.get(parameters, field)

    case value do
      nil -> ValidationStatus.add_error(status, field, "Missing or empty field")
      value when is_binary(value) -> check_if_blank_string(status, field, value)
      value when is_list(value) -> check_if_blank_list(status, field, value)
      _ -> add_unsupported_type_error(status, field)
    end
  end

  defp check_if_blank_string(status, field, value) do
    if is_blank?(value) do
      ValidationStatus.add_error(status, field, "Missing or empty field")
    else
      ValidationStatus.update_value(status, field, value)
    end
  end

  defp is_blank?(field) do
    String.trim(field)
    |> String.length()
    |> is_zero?()
  end

  defp is_zero?(length) do
    length == 0
  end

  defp check_if_blank_list(status, field, value) do
    if is_empty_list?(value) do
      ValidationStatus.add_error(status, field, "Missing or empty field")
    else
      ValidationStatus.update_value(status, field, value)
    end
  end

  defp is_empty_list?(list) do
    length(list) == 0
  end

  defp add_unsupported_type_error(status, field) do
    ValidationStatus.add_error(status, field, "Not a string or list")
  end
end
