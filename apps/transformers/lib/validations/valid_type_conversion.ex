defmodule Transformers.Validations.ValidTypeConversion do

  alias Transformers.ConversionFunctions
  alias Transformers.Validations.ValidationStatus

  def check(status, parameters, source, target, function_field) do
    if prior_errors_on_source_or_target?(status, source, target) do
      status
    else
      attempt_validation(status, parameters, source, target, function_field)
    end
  end

  defp prior_errors_on_source_or_target?(status, source, target) do
    prior_source_type_error? = ValidationStatus.has_error?(status, source)
    prior_target_type_error? = ValidationStatus.has_error?(status, target)
    prior_source_type_error? || prior_target_type_error?
  end

  defp attempt_validation(status, parameters, source, target, function_field) do
    case pick_conversion(parameters) do
      {:ok, conversion_function} -> add_function_to_designated_field(status, function_field, conversion_function)
      {:error, reason} -> add_error_to_source_and_target(status, source, target, reason)
    end
  end

  defp pick_conversion(parameters) do
    source_type = Map.get(parameters, source)
    target_type = Map.get(parameters, target)
    result = ConversionFunctions.pick(source_type, target_type)
  end

  defp add_function_to_designated_field(status, function_field, conversion_function) do
    ValidationStatus.update_value(status, function_field, conversion_function)
  end

  defp add_error_to_source_and_target(status, source, target, reason) do
    ValidationStatus.add_error(status, source, reason)
      |> ValidationStatus.add_error(target, reason)
  end

end
