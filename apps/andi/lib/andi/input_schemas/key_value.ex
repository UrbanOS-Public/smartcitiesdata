defmodule Andi.InputSchemas.KeyValue do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema() do
    field(:key, :string)
    field(:value, :string)
  end

  def changeset(key_value, changes) do
    key_value
    |> cast(changes, [:key, :value])
    |> validate_required([:key, :value])
  end
end
