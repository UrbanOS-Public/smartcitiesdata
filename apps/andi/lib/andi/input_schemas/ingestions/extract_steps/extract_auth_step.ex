defmodule Andi.InputSchemas.Ingestions.ExtractAuthStep do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.Ingestions.ExtractHeader
  alias Andi.InputSchemas.StructTools

  @primary_key false
  embedded_schema do
    field(:body, :string)
    field(:url, :string)
    field(:destination, :string)
    field(:encode_method, :string)
    field(:cacheTtl, :integer, default: 900_000)
    field(:path, {:array, :string})
    embeds_many(:headers, ExtractHeader, on_replace: :delete)
  end

  use Accessible

  @cast_fields [:destination, :encode_method, :path, :cacheTtl, :url, :body]
  @required_fields [:destination, :url, :path, :cacheTtl]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_embed(:headers, with: &ExtractHeader.changeset/2)
    |> validate_body_format()
    |> validate_required(@required_fields, message: "is required")
    |> validate_format(:destination, ~r/^[[:alpha:]_]+$/)
    |> validate_key_value_set(:headers)
    |> validate_path()
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

  defp validate_body_format(%{changes: %{body: body}} = changeset) when body in ["", nil], do: changeset

  defp validate_body_format(%{changes: %{body: body}} = changeset) do
    case Jason.decode(body) do
      {:ok, _} -> changeset
      {:error, _} -> add_error(changeset, :body, "could not parse json", validation: :format)
    end
  end

  defp validate_body_format(changeset), do: changeset

  defp validate_path(%{changes: %{path: []}} = changeset), do: add_error(changeset, :path, "is required")

  defp validate_path(%{changes: %{path: path}} = changeset) do
    case Enum.any?(path, fn path_field -> path_field in ["", nil] end) do
      true -> add_error(changeset, :path, "path fields cannot be empty")
      false -> changeset
    end
  end

  defp validate_path(changeset), do: changeset

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
