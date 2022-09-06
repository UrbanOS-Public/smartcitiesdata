defmodule Transformers.Multiplication do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidationStatus

  @multiplicands "multiplicands"
  @target_field "targetField"

  @impl Transformation
  def transform(payload, parameters) do

    with {:ok, target_field_name} <- FieldFetcher.fetch_value(parameters, @target_field),
          {:ok, multiplicands} <- FieldFetcher.fetch_value(parameters, @multiplicands),
          {:ok, resolved_multiplicands} <-
              resolve_multiplicands_types(payload, multiplicands) do
      {:ok, payload |> Map.put(target_field_name, Enum.reduce(resolved_multiplicands, 1, fn multiplicand, acc -> multiplicand * acc end))}
    end
    #{:ok, payload |> Map.put("output_number", 40)}

    # with {:ok, [source_field, source_format, target_field, target_format]} <-
    #        validate(parameters),
    #      {:ok, payload_source_value} <- FieldFetcher.fetch_value(payload, source_field),
    #      {:ok, source_datetime} <-
    #        string_to_datetime(payload_source_value, source_format, source_field),
    #      {:ok, transformed_datetime} <- format_datetime(source_datetime, target_format) do
    #   {:ok, payload |> Map.put(target_field, transformed_datetime)}
    # else
    #   {:error, reason} ->
    #     {:error, reason}

    #   nil_payload ->
    #     {:ok, nil_payload}
    # end
  end

  defp resolve_multiplicands_types(payload, multiplicands) do
    IO.puts "hello, world part 2"
    #numbers =
     #Enum.map(multiplicands, fn multiplicand -> if is_number(multiplicand), do: multiplicand, else: FieldFetcher.fetch_value(payload, multiplicand) end)
    numbers = for multiplicand <- multiplicands do
      if (is_number(multiplicand)) do
        multiplicand
      else
        case FieldFetcher.fetch_value(payload, multiplicand) do
          {:ok, result} -> result
        end
        # {:ok, result} = FieldFetcher.fetch_value(payload, multiplicand)
        # result
      end
    end

    IO.inspect numbers
    IO.puts "hello, world part 2: electric boogaloo"
  end

  # def validate(parameters) do
  #   %ValidationStatus{}
  #   |> NotBlank.check(parameters, @source_field)
  #   |> NotBlank.check(parameters, @source_format)
  #   |> NotBlank.check(parameters, @target_field)
  #   |> NotBlank.check(parameters, @target_format)
  #   |> DateTimeFormat.check(parameters, @source_format)
  #   |> DateTimeFormat.check(parameters, @target_format)
  #   |> ValidationStatus.ordered_values_or_errors([
  #     @source_field,
  #     @source_format,
  #     @target_field,
  #     @target_format
  #   ])
  # end
end
