defmodule Andi.InputSchemas.Datasets.ExtractS3Step do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.Datasets.ExtractHeader
  alias Andi.InputSchemas.StructTools

  @primary_key false
  embedded_schema do
    field(:url, :string)
    field(:destination, :string)
    embeds_many(:headers, ExtractHeader, on_replace: :delete)
  end

  use Accessible

  @cast_fields [:url]
  @required_fields [:url]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_embed(:headers, with: &ExtractHeader.changeset/2)
    |> validate_required(@required_fields, message: "is required")
    |> validate_key_value_set(:headers)
  end

  def changeset_for_draft(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_embed(:headers, with: &ExtractHeader.changeset_for_draft/2)
  end

  def changeset_from_form_data(form_data) do
    form_data_as_params =
      form_data
      |> AtomicMap.convert(safe: false, underscore: false)
      |> Map.put_new(:headers, %{})
      |> convert_map_with_index_to_list(:headers)

    changeset(form_data_as_params)
  end

  def changeset_from_andi_step(nil), do: changeset(%{})

  def changeset_from_andi_step(dataset_extract_step) do
    dataset_extract_step
    |> StructTools.to_map()
    |> AtomicMap.convert(safe: false, underscore: false)
    |> changeset()
  end

  def preload(struct), do: StructTools.preload(struct, [:headers])

  defp validate_key_value_set(changeset, field) do
    key_value_set = Ecto.Changeset.get_field(changeset, field)

    case key_value_has_invalid_key?(key_value_set) do
      true -> add_error(changeset, field, "has invalid format", validation: :format)
      false -> changeset
    end
  end

  defp key_value_has_invalid_key?(nil), do: false

  defp key_value_has_invalid_key?(key_value_set) do
    Enum.any?(key_value_set, fn key_value -> key_value.key in [nil, ""] end)
  end

  defp convert_map_with_index_to_list(changes, field) do
    map_with_index = Map.get(changes, field)
    key_value_list = Enum.map(map_with_index, fn {_, value} -> value end)
    Map.put(changes, field, key_value_list)
  end
end
