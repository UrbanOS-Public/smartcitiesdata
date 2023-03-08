defmodule Transformers.RegexReplace do
  @behaviour Transformation

  alias Transformers.FieldFetcher
  alias Transformers.Validations.NotBlank
  alias Transformers.Validations.ValidRegex
  alias Transformers.Validations.ValidationStatus
  alias Transformers.Conditions

  @source_field "sourceField"
  @replacement "replacement"
  @regex "regex"

  @impl Transformation
  def transform(payload, parameters) do
    with {:ok, true} <- Conditions.check(payload, parameters),
         {:ok, [source_field, replacement, regex]} <- validate(parameters),
         {:ok, value} <- FieldFetcher.fetch_value(payload, source_field),
         :ok <- abort_if_not_string(value, source_field),
         :ok <- abort_if_not_string(replacement, @replacement) do
      transformed_value = Regex.replace(regex, value, replacement)
      transformed_payload = Map.put(payload, source_field, transformed_value)
      {:ok, transformed_payload}
    else
      {:ok, false} -> {:ok, payload}
      {:error, reason} -> {:error, reason}
    end
  end

  def validate(parameters) do
    %ValidationStatus{}
    |> NotBlank.check(parameters, @source_field)
    |> NotBlank.check(parameters, @replacement)
    |> NotBlank.check(parameters, @regex)
    |> ValidRegex.check(parameters, @regex)
    |> ValidationStatus.ordered_values_or_errors([@source_field, @replacement, @regex])
  end

  defp abort_if_not_string(value, field_name) do
    if is_binary(value) do
      :ok
    else
      {:error, "Value of field #{field_name} is not a string: #{value}"}
    end
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
        field_name: @regex,
        field_type: "string",
        field_label: "Regex",
        options: nil
      },
      %{
        field_name: @replacement,
        field_type: "string",
        field_label: "Replacement",
        options: nil
      }
    ]
  end
end
