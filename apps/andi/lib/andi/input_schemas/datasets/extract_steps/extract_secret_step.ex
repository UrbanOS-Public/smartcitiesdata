defmodule Andi.InputSchemas.Datasets.ExtractSecretStep do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.StructTools

  @primary_key false
  embedded_schema do
    field(:destination, :string)
    field(:key, :string)
    field(:sub_key, :string)
  end

  use Accessible

  @fields [:destination, :key, :sub_key]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> cast(changes_with_id, @fields, empty_values: [])
    |> validate_required(@fields, message: "is required")
  end

  def changeset_for_draft(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> cast(changes_with_id, @fields, empty_values: [])
  end

  def changeset_from_andi_step(nil), do: changeset(%{})

  def changeset_from_andi_step(dataset_date_step) do
    dataset_date_step
    |> StructTools.to_map()
    |> changeset()
  end
end
