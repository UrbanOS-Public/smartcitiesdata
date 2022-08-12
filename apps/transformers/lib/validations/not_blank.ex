defmodule Transformers.Validations.NotBlank do

  alias Transformers.Validations.ValidationStatus

  def check(status, parameters, field) do
    if ValidationStatus.has_error?(status, field) do
      status
    else
      check_if_blank(status, parameters, field)
    end
  end

  defp check_if_blank(status, parameters, field) do
    value = Map.get(parameters, field)

    case value do
      nil -> ValidationStatus.add_error(status, field, "Missing or empty field")
      value when is_binary(value) -> check_if_blank_string(status, field, value)
      value when is_list(value) -> check_if_blank_list(status, field, value)
      _ -> status
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

end
