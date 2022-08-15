defmodule Transformers.Validations.DateTimeFormat do

  alias Transformers.Validations.ValidationStatus

  def check(status, parameters, field) do
    value = Map.get(parameters, field)

    if value == nil do
      add_missing_field_error(status, field)
    else
      check_if_valid(status, field, value)
    end
  end

  defp add_missing_field_error(status, field) do
    ValidationStatus.add_error(status, field, "No datetime format provided")
  end

  defp check_if_valid(status, field, value) do
    result = Timex.Format.DateTime.Formatter.validate(value)
    case result do
      :ok -> ValidationStatus.update_value(status, field, value)
      {:error, reason} -> add_error(status, field, value, reason)
    end
  end

  defp add_error(status, field, value, reason) do
    message = "DateTime format \"#{value}\" is invalid: #{reason}"
    ValidationStatus.add_error(status, field, message)
  end
end
