defmodule Andi.InputSchemas.Datasets.HarvestedDatasets do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "harvested_datasets" do
    field(:orgId, :string)
    field(:sourceId, :string)
    field(:systemId, :string)
    field(:source, :string)
    field(:modifiedDate, :utc_datetime, default: nil)
    field(:include, :boolean, default: true)
  end

  use Accessible

  @cast_fields [:id, :orgId, :sourceId, :systemId, :source, :modifiedDate, :include]
  @required_fields []

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(harvested_dataset, changes) do
    common_changeset_operations(harvested_dataset, changes)
    |> validate_required(@required_fields, message: "is required")
  end

  def changeset_for_draft(harvested_dataset, changes) do
    common_changeset_operations(harvested_dataset, changes)
  end

  defp common_changeset_operations(harvested_dataset, changes) do
    changes_with_id = StructTools.ensure_id(harvested_dataset, changes)

    harvested_dataset
    |> cast(changes_with_id, @cast_fields, empty_values: [])
  end

  def preload(struct), do: struct
end
