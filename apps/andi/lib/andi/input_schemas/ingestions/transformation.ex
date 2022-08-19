defmodule Andi.InputSchemas.Ingestions.Transformation do
  @moduledoc """
  Generic schema for all types of transformations.

  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Ingestion
  alias AndiWeb.Views.Options

  @cast_fields [:id, :type, :name, :parameters, :ingestion_id, :sequence]
  @required_fields [:type, :name, :parameters]

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "transformation" do
    field(:type, :string)
    field(:name, :string)
    field(:parameters, :map)
    field(:sequence, :integer, read_after_writes: true)
    belongs_to(:ingestion, Ingestion, type: Ecto.UUID, foreign_key: :ingestion_id)
  end

  use Accessible

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(transformation, changes) do
    changes_with_id = StructTools.ensure_id(transformation, changes)

    transformation
    |> cast(changes_with_id, @cast_fields)
    |> validate_required(@required_fields, message: "is required")
    |> validate_type()
    |> validate_parameters()
  end

  def changeset_for_draft(changes), do: changeset_for_draft(%__MODULE__{}, changes)

  def changeset_for_draft(transformation, changes) do
    changes_with_id = StructTools.ensure_id(transformation, changes)

    transformation
    |> cast(changes_with_id, @cast_fields)
  end

  def changeset_from_form_data(form_data) do
    form_data_as_params =
      form_data
      |> AtomicMap.convert(safe: false, underscore: false)
      |> wrap_parameters()

    changeset(form_data_as_params)
  end

  defp validate_type(%{changes: %{type: type}} = changeset) do
    transformation_types = Options.transformations() |> Map.new() |> Map.keys()

    case type not in transformation_types do
      true -> add_error(changeset, :type, "invalid type: #{type}")
      false -> changeset
    end
  end

  defp validate_type(changeset), do: changeset

  defp validate_parameters(%{changes: %{type: type, parameters: parameters}} = changeset) do
    converted_parameters = convert_parameters_from_atom_to_string(parameters)

    case Transformers.OperationBuilder.validate(type, converted_parameters) do
      {:ok, _} ->
        changeset

      {:error, reason} when is_binary(reason) ->
        changeset

      {:error, reasons} ->
        Enum.reduce(reasons, changeset, fn {key, value}, changeset ->
          atom_key = String.to_atom(key)
          add_error(changeset, atom_key, value)
        end)
    end
  end

  defp validate_parameters(changeset), do: changeset

  defp convert_parameters_from_atom_to_string(parameters) do
    Map.new(parameters, fn {key, value} -> {Atom.to_string(key), value} end)
  end

  def form_changeset_from_andi_transformation(transformation) do
    transformation
    |> Andi.InputSchemas.StructTools.to_map()
    |> Map.get(:parameters)
  end

  def preload(struct), do: StructTools.preload(struct, [])

  defp wrap_parameters(form_data) do
    parameters =
      form_data
      |> Map.delete(:name)
      |> Map.delete(:id)
      |> Map.delete(:type)

    %{id: form_data.id, name: form_data.name, type: form_data.type, parameters: parameters}
  end

  def convert_andi_transformation_to_changeset(transformation) do
    transformation
    |> StructTools.to_map()
    |> AtomicMap.convert(safe: false, underscore: false)
    |> changeset_for_draft()
  end
end
