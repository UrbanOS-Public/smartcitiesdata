defmodule Andi.InputSchemas.Datasets.ExtractHttpStep do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.Datasets.ExtractQueryParam
  alias Andi.InputSchemas.Datasets.ExtractHeader
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "extract_http_step" do
    field(:assigns, :map)
    field(:body, :string)
    field(:method, :string)
    field(:type, :string)
    field(:url, :string)
    has_many(:headers, ExtractHeader, on_replace: :delete)
    has_many(:queryParams, ExtractQueryParam, on_replace: :delete)
    belongs_to(:technical, Technical, type: Ecto.UUID, foreign_key: :technical_id)
  end

  use Accessible

  @cast_fields [:id, :type, :method, :url, :body, :assigns, :technical_id]
  @required_fields [:type, :method, :url, :assigns]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes) |> Map.put(:assigns, %{})

    extract_step
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:headers, with: &ExtractHeader.changeset/2)
    |> cast_assoc(:queryParams, with: &ExtractQueryParam.changeset/2)
    |> foreign_key_constraint(:technical_id)
    |> validate_required(@required_fields, message: "is required")
    |> validate_key_value_parameters()
  end

  def changeset_for_draft(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes) |> Map.put(:assigns, %{})

    extract_step
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> cast_assoc(:headers, with: &ExtractHeader.changeset_for_draft/2)
    |> cast_assoc(:queryParams, with: &ExtractQueryParam.changeset_for_draft/2)
    |> foreign_key_constraint(:technical_id)
  end

  def changeset_from_form_data(form_data) do
    form_data_as_params =
      form_data
      |> AtomicMap.convert(safe: false, underscore: false)
      |> Map.put_new(:queryParams, %{})
      |> Map.put_new(:headers, %{})

    changeset(form_data_as_params)
  end

  def changeset_from_andi_step(nil, technical_id), do: changeset(%{type: "http", technical_id: technical_id, assigns: %{}})

  def changeset_from_andi_step(dataset_http_step, _technical_id) do
    dataset_http_step
    |> StructTools.to_map
    |> changeset()
  end

  def preload(struct), do: StructTools.preload(struct, [:headers, :queryParams])

  defp validate_key_value_parameters(changeset) do
    [:queryParams, :headers]
    |> Enum.reduce(changeset, fn field, acc_changeset ->
      acc_changeset = clear_field_errors(acc_changeset, field)

      if has_invalid_key_values?(acc_changeset, field) do
        add_error(acc_changeset, field, "has invalid format", validation: :format)
      else
        acc_changeset
      end
    end)
  end

  defp has_invalid_key_values?(%{changes: changes}, field) do
    case Map.get(changes, field) do
      nil ->
        false

      key_value_changesets ->
        Enum.any?(key_value_changesets, fn key_value_changeset -> not key_value_changeset.valid? end)
    end
  end

  defp clear_field_errors(changset, field) do
    Map.update(changset, :errors, [], fn errors -> Keyword.delete(errors, field) end)
  end
end
