defmodule Andi.InputSchemas.Datasets.Dataset do
  @moduledoc """
  Module for validating Ecto.Changesets on flattened dataset input.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Business
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.StructTools

  @primary_key {:id, :string, autogenerate: false}
  schema "datasets" do
    has_one(:technical, Technical, on_replace: :update)
    has_one(:business, Business, on_replace: :update)
    field(:ingestedTime, :utc_datetime, default: nil)
    has_many(:data_dictionaries, DataDictionary)
  end

  use Accessible

  @cast_fields [:id, :ingestedTime]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(dataset, changes) do
    dataset
    |> cast(changes, @cast_fields)
    |> cast_assoc(:technical, with: &Technical.changeset/2)
    |> cast_assoc(:business, with: &Business.changeset/2)
  end

  def changeset_for_draft(dataset, changes) do
    dataset
    |> cast(changes, @cast_fields)
    |> cast_assoc(:technical, with: &Technical.changeset_for_draft/2)
    |> cast_assoc(:business, with: &Business.changeset_for_draft/2)
  end

  def preload(struct), do: StructTools.preload(struct, [:technical, :business])

  def full_validation_changeset(changes), do: full_validation_changeset(%Andi.InputSchemas.Datasets.Dataset{}, changes)

  def full_validation_changeset(schema, changes) do
    changeset(schema, changes) |> validate_unique_system_name()
  end

  def validate_unique_system_name(changeset) do
    id = Ecto.Changeset.get_field(changeset, :id)
    technical = Ecto.Changeset.get_change(changeset, :technical, Technical.changeset(%Technical{}, %{}))
    data_name = Ecto.Changeset.get_field(technical, :dataName)
    org_name = Ecto.Changeset.get_field(technical, :orgName)

    unless Datasets.is_unique?(id, data_name, org_name) do
      updated_technical_changeset = add_data_name_error(technical)
      Ecto.Changeset.put_change(changeset, :technical, updated_technical_changeset)
    else
      changeset
    end
  end

  defp add_data_name_error(nil), do: nil

  defp add_data_name_error(technical_changeset) do
    technical_changeset
    |> clear_data_name_errors()
    |> add_error(:dataName, "existing dataset has the same orgName and dataName")
  end

  defp clear_data_name_errors(technical_changeset) do
    cleared_errors =
      technical_changeset.errors
      |> Keyword.drop([:dataName])

    Map.put(technical_changeset, :errors, cleared_errors)
  end
end
