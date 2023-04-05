defmodule Transformers.TypeConversion do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidTypeConversion
  alias Transformers.Validations.ValidationStatus
  alias Transformers.Validations.DateTimeFormat
  alias Transformers.Conditions

  @field "field"
  @source_type "sourceType"
  @target_type "targetType"
  @conversion_function "conversionFunction"
  @date_format "conversionDateFormat"

  @impl Transformation
  def transform(payload, params) do
    with {:ok, true} <- Conditions.check(payload, params),
         {:ok, [field, source_type, target_type, conversion_function, date_format]} <-
           validate(params),
         {:ok, value} <- FieldFetcher.fetch_value(payload, field),
         :ok <- abort_if_missing_value(payload, field, value),
         :ok <- check_field_is_of_sourcetype(field, value, source_type) do
      parse_or_error(conversion_function, payload, field, value, target_type, date_format)
    else
      {:ok, false} -> {:ok, payload}
      {:error, reason} -> {:error, reason}
      nil_payload -> {:ok, nil_payload}
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @field)
    |> NotBlank.check(parameters, @source_type)
    |> NotBlank.check(parameters, @target_type)
    |> check_datetime(parameters)
    |> ValidTypeConversion.check(parameters, @source_type, @target_type, @conversion_function)
    |> ValidationStatus.ordered_values_or_errors([
      @field,
      @source_type,
      @target_type,
      @conversion_function,
      @date_format
    ])
  end

  defp check_datetime(status, parameters) do
    source_type = Map.get(parameters, @source_type)
    target_type = Map.get(parameters, @target_type)

    if Enum.any?([source_type, target_type], fn type -> type == "datetime" end) do
      NotBlank.check(status, parameters, @date_format)
      |> DateTimeFormat.check(parameters, @date_format)
    else
      status
    end
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
        "datetime" -> fn value -> Timex.is_valid?(value) end
      end

    if function.(value) do
      :ok
    else
      {:error, "Field #{field} not of expected type: #{source_type}"}
    end
  end

  defp parse_or_error(conversion_function, payload, field, value, target_type, date_format)
       when not is_nil(date_format) do
    try do
      {status, transformed_value} = conversion_function.([value, date_format])
      if status == :error, do: raise({:error, transformed_value})
      transformed_payload = Map.put(payload, field, transformed_value)
      {:ok, transformed_payload}
    rescue
      _ -> {:error, "Cannot parse field #{field} with value #{value} into #{target_type}"}
    end
  end

  defp parse_or_error(conversion_function, payload, field, value, target_type, date_format) do
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
        options: ["integer", "string", "float", "datetime"]
      },
      %{
        field_name: @target_type,
        field_type: "string",
        field_label: "Target Data Type",
        options: ["integer", "string", "float", "datetime"]
      },
      %{
        field_name: @date_format,
        field_type: "string",
        field_label: "Date Format",
        options: nil
      }
    ]
  end
end
