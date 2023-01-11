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

  def new(%__MODULE__{id: nil} = data) do
    changes_as_map = StructTools.to_map(data)

    change(%__MODULE__{}, changes_as_map)
  end

  def new(%__MODULE__{id: something} = data) do
    raise InvalidId, message: "Attempted to create a new #{__MODULE__} with an ID present. Use lift/1 if this was intended."
  end

  def lift(%__MODULE__{} = data) do
    changes_as_map = StructTools.to_map(data)
    current_data = Repo.get!(Codelabs.Address, data.id)

    current_data
    |> change(changes_as_map)
  end

  def insert(%__MODULE__{} = data) do
    data
    |> Changeset.cast(%{}, [])
    |> Repo.insert()
  end

  def change(%__MODULE__{} = data, %{} = changes) do
    # TODO test
    data
    |> Changeset.cast(changes, @cast_fields)
  end

  def change(%Ecto.Changeset{data: %__MODULE__{}} = changeset, %{} = changes) do
    # TODO test
    changeset
    |> Changeset.cast(changes, @cast_fields)
  end

  def validate(%Ecto.Changeset{data: %__MODULE__{}} = changeset) do
    changeset
    |> Map.put(:errors, [])
    |> raise_if_underlying_data_invalid
  end

  defp raise_if_underlying_data_invalid(original_changeset) do
    changes_as_map =
      original_changeset.data
      |> StructTools.to_map()

    underlying_data_errors =
      original_changeset.data
      |> change(changes_as_map)
      |> Map.get(:errors)

    case underlying_data_errors do
      [] ->
        original_changeset

      errors ->
        IO.inspect(original_changeset, label: "InvalidUnderlyingData - Changeset")
        IO.inspect(underlying_data_errors, label: "InvalidUnderlyingData - Errors")

        raise InvalidUnderlyingData,
          message:
            "Found basic errors in existing data within a changeset. This likely means the changeset was improperly created or modified."
    end
  end
end
