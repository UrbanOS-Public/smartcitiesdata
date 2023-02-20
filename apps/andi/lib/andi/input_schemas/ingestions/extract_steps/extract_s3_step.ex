defmodule Andi.InputSchemas.Ingestions.ExtractS3Step do
  @moduledoc false
  use Ecto.Schema

  alias Andi.InputSchemas.Ingestions.ExtractHeader
  alias Andi.InputSchemas.StructTools
  alias Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:url, :string)
    field(:destination, :string)
    embeds_many(:headers, ExtractHeader, on_replace: :delete)
  end

  use Accessible

  @cast_fields [:url]
  @required_fields [:url]

  def get_module(), do: %__MODULE__{}

  def changeset(extract_step, changes) do
    changes_with_id =
      StructTools.ensure_id(extract_step, changes)
      |> AtomicMap.convert(safe: false, underscore: false)

    extract_step
    |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [])
    |> Changeset.cast_embed(:headers, with: &ExtractHeader.changeset/2)
  end

  def validate(extract_step_changeset) do
    data_as_changes =
      extract_step_changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()

    validated_extract_step_changeset =
      extract_step_changeset
      |> Map.replace(:errors, [])
      |> Changeset.cast(data_as_changes, @cast_fields, empty_values: [], force_changes: true)
      |> Changeset.cast_embed(:headers, with: &ExtractHeader.changeset/2)
      |> Changeset.validate_required(@required_fields, message: "is required")
      |> validate_headers()

    if is_nil(Map.get(validated_extract_step_changeset, :action, nil)) do
      Map.put(validated_extract_step_changeset, :action, :display_errors)
    else
      validated_extract_step_changeset
    end
  end

  def changeset_for_draft(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [])
    |> Changeset.cast_embed(:headers, with: &ExtractHeader.changeset_for_draft/2)
  end

  def preload(struct), do: StructTools.preload(struct, [:headers])

  defp validate_headers(changeset) do
    headers =
      case Changeset.fetch_field(changeset, :headers) do
        {_, headers} -> headers
        :error -> []
      end

    Enum.reduce(headers, changeset, fn header, acc ->
      validated_header_changeset =
        ExtractHeader.changeset(header, %{})
        |> ExtractHeader.validate()

      Enum.reduce(validated_header_changeset.errors, acc, fn {_key, {message, _}}, error_acc ->
        Changeset.add_error(error_acc, :headers, message)
      end)
    end)
  end

  # defp validate_key_value_set(changeset, field) do
  #   key_value_set = Ecto.Changeset.get_field(changeset, field)

  #   case key_value_has_invalid_key?(key_value_set) do
  #     true -> Changeset.add_error(changeset, field, "has invalid format", validation: :format)
  #     false -> changeset
  #   end
  # end

  # defp key_value_has_invalid_key?(nil), do: false

  # defp key_value_has_invalid_key?(key_value_set) do
  #   Enum.any?(key_value_set, fn key_value -> key_value.key in [nil, ""] end)
  # end
end
