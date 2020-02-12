defmodule Andi.InputSchemas.KeyValue do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema() do
    field(:id, Ecto.UUID, default: Ecto.UUID.generate())
    field(:key, :string)
    field(:value, :string)
  end

  def changeset(key_value, changes) do
    key_value
    |> cast(changes, [:id, :key, :value])
    |> validate_required([:id, :key, :value]) #TODO: value should not be required
  end
end
