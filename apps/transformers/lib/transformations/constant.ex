defmodule Transformers.Constant do
  @behaviour Transformation

  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus
  alias Transformers.Conditions

  @target_field "targetField"
  @new_value "newValue"
  @value_type "valueType"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, true} <- Conditions.check(payload, parameters),
         {:ok, [target_field, new_value, value_type]} <- validate(parameters) do
      convert_value(new_value, value_type, payload, target_field)
    else
      {:ok, false} -> {:ok, payload}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @target_field)
    |> NotBlank.check(parameters, @new_value)
    |> NotBlank.check(parameters, @value_type)
    |> ValidationStatus.ordered_values_or_errors([@target_field, @new_value, @value_type])
  end

  defp convert_value(value, value_type, payload, target_field) do
    try do
      case convert(value, value_type) do
        :error ->
          raise "Error: could not convert '#{value}' to type: #{value_type}"

        {parsed_value, _} ->
          converted_payload = Map.put(payload, target_field, parsed_value)
          {:ok, converted_payload}
      end
    rescue
      err -> {:error, if(is_map_key(err, :message), do: err.message, else: err)}
    end
  end

  defp convert(value, value_type) do
    case value_type do
      "string" -> {value, ""}
      "integer" -> Integer.parse(value, 10)
      "float" -> Float.parse(value)
      _ -> raise "Error: Invalid conversion type: #{value_type}"
    end
  end

  def fields() do
    [
      %{
        field_name: @target_field,
        field_type: "string",
        field_label: "Target Field"
      },
      %{
        field_name: @new_value,
        field_type: "string",
        field_label: "Value to replace in source field"
      },
      %{
        field_name: @value_type,
        field_type: "string",
        field_label: "Data type",
        options: ["integer", "string", "float"]
      }
    ]
  end
end
