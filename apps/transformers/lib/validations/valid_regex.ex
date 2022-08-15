defmodule Transformers.Validations.ValidRegex do

  alias Transformers.RegexUtils
  alias Transformers.Validations.ValidationStatus

  def check(status, parameters, field) do
    value = Map.get(parameters, field)

    if value == nil do
      add_missing_value_error(status, field)
    else
      attempt_validation(status, field, value)
    end
  end

  defp add_missing_value_error(status, field) do
    ValidationStatus.add_error(status, field, "No regular expression provided")
  end

  defp attempt_validation(status, field, value) do
    result = RegexUtils.regex_compile(value)

    case result do
      {:ok, compiled} -> ValidationStatus.update_value(status, field, compiled)
      {:error, reason} -> ValidationStatus.add_error(status, field, reason)
    end
  end
end
