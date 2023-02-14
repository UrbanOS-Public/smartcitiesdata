defmodule Andi.InputSchemas.Ingestions.ExtractDateStep do
  @moduledoc false
  use Ecto.Schema

  alias Timex.Format.DateTime.Formatter
  alias Andi.InputSchemas.StructTools
  alias Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  embedded_schema do
    field(:destination, :string)
    field(:deltaTimeUnit, :string)
    field(:deltaTimeValue, :integer)
    field(:format, :string)
  end

  use Accessible

  @cast_fields [:id, :format, :deltaTimeValue, :deltaTimeUnit, :destination]
  @required_fields [:format, :destination]

  def get_module(), do: %__MODULE__{}

  def changeset(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)
      |> scrub_time_value()

    extract_step
    |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [])
  end

  def validate(extract_step_changeset) do
    data_as_changes =
      extract_step_changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()
      |> format()

    validated_extract_step_changeset = extract_step_changeset
      |> Map.replace(:errors, [])
      |> Changeset.cast(data_as_changes, @cast_fields, empty_values: [], force_changes: true)
      |> Changeset.validate_required(@required_fields, message: "is required")
      |> validate_time_unit()
      |> validate_delta_change()
      |> Changeset.validate_format(:destination, ~r/^[[:alpha:]_]+$/)
      |> validate_timex_format()

      if is_nil(Map.get(validated_extract_step_changeset, :action, nil)) do
        Map.put(validated_extract_step_changeset, :action, :display_errors)
      else
        validated_extract_step_changeset
      end
  end

  def preload(struct), do: struct

  defp scrub_time_value(%{"deltaTimeValue" => ""} = changes), do: Map.put(changes, "deltaTimeValue", nil)
  defp scrub_time_value(changes), do: changes

  defp format(changes) do
    changes
      |> format_format()
  end

  defp format_format(%{format: _format} = changes), do: changes
  defp format_format(changes), do: Map.put(changes, :format, "{YYYY}-{0M}-{0D} {h24}:{m}:{s}")

  defp validate_timex_format(%{changes: %{format: format}} = changeset) do
    case Formatter.validate(format) do
      :ok ->
        changeset

      {:error, %RuntimeError{message: error_msg}} ->
        Changeset.add_error(changeset, :format, error_msg)

      {:error, err} ->
        Changeset.add_error(changeset, :format, err)
    end
  end
  defp validate_timex_format(changeset), do: changeset

  defp validate_time_unit(%{changes: %{deltaTimeUnit: unit}} = changeset)
       when unit in ["microseconds", "milliseconds", "seconds", "minutes", "hours", "days", "weeks", "months", "years", ""],
       do: changeset

  defp validate_time_unit(%{changes: %{deltaTimeUnit: _unit}} = changeset), do: Changeset.add_error(changeset, :deltaTimeUnit, "invalid time unit")

  defp validate_time_unit(changeset), do: changeset

  defp validate_delta_change(%{changes: %{deltaTimeUnit: delta_time_unit}} = changeset) when delta_time_unit not in [nil, ""] do
    case Changeset.get_change(changeset, :deltaTimeValue) in [nil, ""] do
      true -> Changeset.add_error(changeset, :deltaTimeValue, "must be set when deltaTimeUnit is set")
      false -> changeset
    end
  end

  defp validate_delta_change(%{changes: %{deltaTimeValue: delta_time_value}} = changeset) when delta_time_value not in [nil, ""] do
    case Changeset.get_change(changeset, :deltaTimeUnit) in [nil, ""] do
      true -> Changeset.add_error(changeset, :deltaTimeUnit, "must be set when deltaTimeValue is set")
      false -> changeset
    end
  end

  defp validate_delta_change(changeset), do: changeset
end
