defmodule Andi.InputSchemas.DataDictionary do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset
  alias Andi.InputSchemas.DataDictionary

  @primary_key false
  embedded_schema do
    field(:id, Ecto.UUID)
    field(:name, :string)
    field(:type, :string)
    field(:itemType, :string)
    field(:selector, :string)
    field(:biased, :string)
    field(:demographic, :string)
    field(:description, :string)
    field(:masked, :string)
    field(:pii, :string)
    embeds_many(:subSchema, DataDictionary)
  end

  def changeset(key_value, %DataDictionary{} = dictish_changes) do
    changeset(key_value, Map.from_struct(dictish_changes))
  end

  def changeset(key_value, changes) do
    with_id = Map.put_new(changes, :id, Ecto.UUID.generate())

    key_value
    |> cast(with_id, [:id, :name, :type, :selector, :itemType, :biased, :demographic, :description, :masked, :pii], empty_values: [])
    |> cast_embed(:subSchema)
    |> validate_required([:id, :name, :type])
  end

  def relationship_definition(field) do
    %Ecto.Embedded{
      cardinality: :many,
      field: field,
      on_cast: &DataDictionary.changeset(&1, &2),
      on_replace: :delete,
      owner: nil,
      related: DataDictionary
    }
  end
end
