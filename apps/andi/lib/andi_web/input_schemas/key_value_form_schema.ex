defmodule AndiWeb.InputSchemas.KeyValueFormSchema do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools

  @primary_key false
  embedded_schema do
    field(:id, Ecto.UUID, autogenerate: true)
    field(:key, :string)
    field(:value, :string)
  end

  @cast_fields [:id, :key, :value]

  use Accessible

  def changeset(changeset, changes) do
    changes_with_id = StructTools.ensure_id(changeset, changes)
      |> AtomicMap.convert(safe: false, underscore: false)

    changeset
      |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [])
  end
end
