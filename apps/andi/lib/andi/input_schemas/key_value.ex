defmodule Andi.InputSchemas.KeyValue do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, Ecto.UUID)
    field(:key, :string)
    field(:value, :string)
  end

  def changeset(key_value, changes) do
    with_id = Map.put_new(changes, :id, Ecto.UUID.generate())

    key_value
    |> cast(with_id, [:id, :key, :value], empty_values: [])
    |> validate_required([:id, :key])
  end

  def relationship_definition(field) do
    %Ecto.Embedded{
      cardinality: :many,
      field: field,
      on_cast: &Andi.InputSchemas.KeyValue.changeset(&1, &2),
      on_replace: :delete,
      owner: nil,
      related: Andi.InputSchemas.KeyValue
    }
  end
end
