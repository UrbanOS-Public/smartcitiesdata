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
    validation_changeset = changeset
                           |> Map.replace(:errors, [])
                           |> Changeset.cast(data_as_changes, @cast_fields, force_changes: true)
                           |> Changeset.cast_assoc(:addresses, with: &Codelabs.Address.changeset/2)
                           |> Changeset.validate_length(:name, max: 10)
  end
end
