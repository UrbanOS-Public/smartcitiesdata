defmodule Codelabs.Person do
  use Ecto.Schema
  use Properties, otp_app: :andi

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools
  alias Andi.Repo

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "person" do
    field(:name, :string)
    field(:age, :integer)
    has_many(:addresses, Codelabs.Address, on_replace: :delete)
  end

  @cast_fields [
    :id,
    :name,
    :age
  ]

  @required_fields [
    :id,
    :name,
    :age,
    :addresses
  ]

  def changeset(current, changes) do
    current
    |> Changeset.cast(changes, @cast_fields)
    |> Changeset.cast_assoc(:addresses, with: &Codelabs.Address.changeset/2)
  end

  def validate(%Ecto.Changeset{data: %__MODULE__{}} = changeset) do
    # Extract data from changeset, including changes
    data_as_changes =
      changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()

    # Since validations have varying behavior, its better to create a new changeset to validate everything as a new change
    validation_changeset =
      changeset(%__MODULE__{}, data_as_changes)
      |> Changeset.validate_length(:name, max: 10)

    # Copy our validation fields from the fresh changeset into the actual changeset
    changeset
    |> Map.replace(:errors, validation_changeset.errors)
    |> Map.replace(:valid?, validation_changeset.valid?)
  end
end
