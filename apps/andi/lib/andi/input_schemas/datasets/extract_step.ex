defmodule Andi.InputSchemas.Datasets.ExtractStep do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  schema "extract_step" do
    field(:type, :string)
    field(:context, :map)
    field(:assigns, :map)

    belongs_to(:technical, Technical, type: Ecto.UUID, foreign_key: :technical_id)
  end

  use Accessible

  @cast_fields [:type, :context, :assigns]
  @required_fields [:type, :context, :assigns]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(extract_step, changes) do
    extract_step
    |> cast(changes, @cast_fields, empty_values: [])
    |> validate_required(@required_fields, message: "is required")
  end
end
