defmodule Codelabs.Address do
  use Ecto.Schema
  use Properties, otp_app: :andi

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools

  defmodule InvalidId do
    defexception [:message, :field]
  end

  defmodule InvalidUnderlyingData do
    defexception [:message, :field]
  end

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "address" do
    field(:street, :string)
    belongs_to(:person, Codelabs.Person, foreign_key: :person_id, type: Ecto.UUID)
  end

  @cast_fields [
    :street,
    :person_id,
    :id
  ]

  @required_fields [
    :street
  ]

  def changeset(current, changes) do
    current
    |> Changeset.cast(changes, @cast_fields)
  end
end
