defmodule Transformers.RegexExtract do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidRegex
  alias Transformers.Validations.ValidationStatus
  alias Transformers.Conditions

  @source_field "sourceField"
  @target_field "targetField"
  @regex "regex"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, true} <- Conditions.check(payload, parameters),
         {:ok, [source_field, target_field, regex]} <- validate(parameters),
         {:ok, value} when value != nil <-
           FieldFetcher.fetch_value(payload, source_field) do
      try do
        case Regex.run(regex, value, capture: :all_but_first) do
          nil ->
            transformed_payload = Map.put(payload, target_field, nil)
            {:ok, transformed_payload}

          [extracted_value | _] ->
            transformed_payload = Map.put(payload, target_field, extracted_value)
            {:ok, transformed_payload}
        end
      rescue
        error ->
          {:error,
           "Regex Extract Transformation Error: Failure to parse REGEX: #{inspect(regex)} from VALUE: #{
             inspect(value)
           } of SOURCE_FIELD: #{inspect(source_field)}"}
      end
    else
      {:ok, false} ->
        {:ok, payload}

      {:ok, nil} ->
        {:ok, payload}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @source_field)
    |> NotBlank.check(parameters, @target_field)
    |> NotBlank.check_nested(parameters, @source_field)
    |> NotBlank.check_nested(parameters, @target_field)
    |> NotBlank.check(parameters, @regex)
    |> ValidRegex.check(parameters, @regex)
    |> ValidationStatus.ordered_values_or_errors([@source_field, @target_field, @regex])
  end

  def fields() do
    [
      %{
        field_name: @source_field,
        field_type: "string",
        field_label: "Source Field",
        options: nil
      },
      %{
        field_name: @target_field,
        field_type: "string",
        field_label: "Target Field",
        options: nil
      },
      %{
        field_name: @regex,
        field_type: "string",
        field_label: "Regex",
        options: nil
      }
    ]
  end
end
