defmodule AndiWeb.InputSchemas.UrlFormSchema do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.Options
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets.Header
  alias Andi.InputSchemas.Datasets.QueryParam

  schema "url" do
    field(:sourceUrl, :string)
    has_many(:sourceHeaders, Header, on_replace: :delete)
    has_many(:sourceQueryParams, QueryParam, on_replace: :delete)
  end

  use Accessible

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(url, changes) do
    changes_with_id = StructTools.ensure_id(url, changes)
    url
    |> cast(changes_with_id, [:sourceUrl], empty_values: [])
    |> cast_assoc(:sourceHeaders, with: &Header.changeset/2)
    |> cast_assoc(:sourceQueryParams, with: &QueryParam.changeset/2)
    |> validate_required([:sourceUrl], message: "is required")
    |> validate_key_value_parameters()
  end

  def changeset_from_andi_dataset(dataset) do
    dataset = StructTools.to_map(dataset)
    technical_changes = dataset.technical

    changeset(technical_changes)
  end


  # TODO
  # def changeset_for_draft(dataset, changes) do
  #   dataset
  #   |> cast(changes, @cast_fields)
  #   |> cast_assoc(:technical, with: &Technical.changeset_for_draft/2)
  #   |> cast_assoc(:business, with: &Business.changeset_for_draft/2)
  # end

  defp validate_key_value_parameters(changeset) do
    [:sourceQueryParams, :sourceHeaders]
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
