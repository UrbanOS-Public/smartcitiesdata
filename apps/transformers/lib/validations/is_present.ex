defmodule Transformers.Validations.IsPresent do

  alias Transformers.Validations.ValidationStatus

  def check(status, parameters, field) do
    value = Map.get(parameters, field)

    case value do
      nil -> ValidationStatus.add_error(status, field, "Missing field")
      _ -> ValidationStatus.update_value(status, field, value)
    end
  end

end
