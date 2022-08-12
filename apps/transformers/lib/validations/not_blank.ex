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

    if is_blank?(value) do
      ValidationStatus.add_error(status, field, "Missing or empty field")
    else
      ValidationStatus.update_value(status, field, value)
    end
  end

  defp is_blank?(field) do
    field == nil || String.trim(field)
      |> String.length()
      |> is_zero?()
  end

  defp is_zero?(length) do
    length == 0
  end

end
