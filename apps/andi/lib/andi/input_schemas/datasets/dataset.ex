defmodule Andi.InputSchemas.Datasets.Dataset do
  @moduledoc """
  Module for validating Ecto.Changesets on flattened dataset input.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.Schemas.User
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Business
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Organization

  @primary_key {:id, :string, autogenerate: false}
  schema "datasets" do
    field(:dlq_message, :map)
    field(:datasetLink, :string)
    field(:ingestedTime, :utc_datetime, default: nil)
    field(:version, :string)
    field(:submission_status, Ecto.Enum, values: [:published, :approved, :rejected, :submitted, :draft], default: :draft)
    belongs_to(:owner, User, type: Ecto.UUID, foreign_key: :owner_id)
    belongs_to(:organization, Organization, type: Ecto.UUID, foreign_key: :organization_id)
    has_many(:data_dictionaries, DataDictionary)
    has_one(:business, Business, on_replace: :update)
    has_one(:technical, Technical, on_replace: :update)
  end

  use Accessible

  @cast_fields [:id, :ingestedTime, :version, :submission_status, :dlq_message, :owner_id, :datasetLink, :organization_id]

  @submission_required_fields [:datasetLink]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(dataset, changes) do
    dataset
    |> cast(changes, @cast_fields)
    |> cast_assoc(:technical, with: &Technical.changeset/2)
    |> cast_assoc(:business, with: &Business.changeset/2)
  end

  def submission_changeset(changes), do: submission_changeset(%__MODULE__{}, changes)

  def submission_changeset(dataset, changes) do
    dataset
    |> cast(changes, @cast_fields)
    |> validate_required(@submission_required_fields, message: "is required")
    |> cast_assoc(:technical, with: &Technical.submission_changeset/2)
    |> cast_assoc(:business, with: &Business.submission_changeset/2)
  end

  def changeset_for_draft(dataset, %{owner: owner} = changes) do
    dataset
    |> cast(changes, @cast_fields)
    |> put_assoc(:owner, owner)
    |> cast_assoc(:technical, with: &Technical.changeset_for_draft/2)
    |> cast_assoc(:business, with: &Business.changeset_for_draft/2)
  end

  def changeset_for_draft(dataset, %{owner: owner, organization: organization} = changes) do
    dataset
    |> cast(changes, @cast_fields)
    |> put_assoc(:owner, owner)
    |> put_assoc(:organization, organization)
    |> cast_assoc(:technical, with: &Technical.changeset_for_draft/2)
    |> cast_assoc(:business, with: &Business.changeset_for_draft/2)
  end

  def changeset_for_draft(dataset, %{organization: organization} = changes) do
    dataset
    |> cast(changes, @cast_fields)
    |> put_assoc(:organization, organization)
    |> cast_assoc(:technical, with: &Technical.changeset_for_draft/2)
    |> cast_assoc(:business, with: &Business.changeset_for_draft/2)
  end

  def changeset_for_draft(dataset, changes) do
    dataset
    |> cast(changes, @cast_fields)
    |> cast_assoc(:technical, with: &Technical.changeset_for_draft/2)
    |> cast_assoc(:business, with: &Business.changeset_for_draft/2)
  end

  def preload(struct), do: StructTools.preload(struct, [:technical, :business, :owner, :organization])

  def full_validation_changeset(changes), do: full_validation_changeset(%__MODULE__{}, changes)

  def full_validation_changeset(schema, changes) do
    changeset(schema, changes)
    |> validate_unique_system_name()
  end

  def validate_unique_system_name(%{changes: %{technical: technical}} = changeset) do
    id = Ecto.Changeset.get_field(changeset, :id)
    data_name = Ecto.Changeset.get_change(technical, :dataName)
    org_id = Ecto.Changeset.get_field(changeset, :organization_id)
    case is_nil(org_id) do
      false ->
        org = Andi.InputSchemas.Organizations.get(org_id)
        technical_changeset = check_uniqueness(technical, id, data_name, org.orgName)
        Ecto.Changeset.put_change(changeset, :technical, technical_changeset)
      _ -> 
        technical_changeset = check_uniqueness(technical, id, data_name, nil)
        Ecto.Changeset.put_change(changeset, :technical, technical_changeset)
    end
    
  end

  def validate_unique_system_name(changeset) do
    id = Ecto.Changeset.get_field(changeset, :datasetId)
    data_name = Ecto.Changeset.get_change(changeset, :dataName)
    org_name = Ecto.Changeset.get_change(changeset, :orgName)

    check_uniqueness(changeset, id, data_name, org_name)
  end

  defp check_uniqueness(changeset, id, data_name, org_name) do
    case Datasets.is_unique?(id, data_name, org_name) do
      false ->
        add_data_name_error(changeset)

      _ ->
        changeset
    end
  end

  defp add_data_name_error(nil), do: nil

  defp add_data_name_error(changeset) do
    changeset
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
