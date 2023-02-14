defmodule Transformers.TypeConversion do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidTypeConversion
  alias Transformers.Validations.ValidationStatus

  @field "field"
  @source_type "sourceType"
  @target_type "targetType"
  @conversion_function "conversionFunction"

  @impl Transformation
  def transform(payload, params) do
    with {:ok, [field, source_type, target_type, conversion_function]} <- validate(params),
         {:ok, value} <- FieldFetcher.fetch_value(payload, field),
         :ok <- abort_if_missing_value(payload, field, value),
         :ok <- check_field_is_of_sourcetype(field, value, source_type) do
      parse_or_error(conversion_function, payload, field, value, target_type)
    else
      {:error, reason} -> {:error, reason}
      nil_payload -> {:ok, nil_payload}
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @field)
    |> NotBlank.check(parameters, @source_type)
    |> NotBlank.check(parameters, @target_type)
    |> ValidTypeConversion.check(parameters, @source_type, @target_type, @conversion_function)
    |> ValidationStatus.ordered_values_or_errors([
      @field,
      @source_type,
      @target_type,
      @conversion_function
    ])
  end

  defp abort_if_missing_value(payload, field, value) do
    if(value == nil or value == "") do
      Map.put(payload, field, nil)
    else
      :ok
    end
  end

  defp check_field_is_of_sourcetype(field, value, source_type) do
    function =
      case source_type do
        "float" -> fn value -> is_float(value) end
        "integer" -> fn value -> is_integer(value) end
        "string" -> fn value -> is_binary(value) end
      end

    if function.(value) do
      :ok
    else
      {:error, "Field #{field} not of expected type: #{source_type}"}
    end
  end

  defp parse_or_error(conversion_function, payload, field, value, target_type) do
    try do
      transformed_value = conversion_function.(value)
      transformed_payload = Map.put(payload, field, transformed_value)
      {:ok, transformed_payload}
    rescue
      _ -> {:error, "Cannot parse field #{field} with value #{value} into #{target_type}"}
    end
  end

  def fields() do
    [
      %{
        field_name: @field,
        field_type: "string",
        field_label: "Field to Convert",
        options: nil
      },
      %{
        field_name: @source_type,
        field_type: "string",
        field_label: "Source Data Type",
        options: ["integer", "string", "float"]
      },
      %{
        field_name: @target_type,
        field_type: "string",
        field_label: "Target Data Type",
        options: ["integer", "string", "float"]
      }
    ]
  end
end
