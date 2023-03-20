defmodule Andi.InputSchemas.Ingestions.Transformation do
  @moduledoc """
  Generic schema for all types of transformations.
  """
  use Ecto.Schema

  alias Ecto.Changeset
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

  def get_module(), do: %__MODULE__{}

  def changeset(transformation, changes) do
    changes_with_id =
      StructTools.ensure_id(transformation, changes)
      |> AtomicMap.convert(safe: false, underscore: false)
      |> format_parameters()

    transformation
    |> Changeset.cast(changes_with_id, @cast_fields, empty_values: [], force_changes: true)
  end

  def validate(transformation_changeset) do
    data_as_changes =
      transformation_changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()

    validated_transformation_changeset =
      transformation_changeset
      |> Map.replace(:errors, [])
      |> Changeset.cast(data_as_changes, @cast_fields, force_changes: true)
      |> Changeset.validate_required(@required_fields, message: "is required")
      |> validate_type()
      |> validate_parameters()

    if is_nil(Map.get(validated_transformation_changeset, :action, nil)) do
      Map.put(validated_transformation_changeset, :action, :display_errors)
    else
      validated_transformation_changeset
    end
  end

  def preload(struct), do: StructTools.preload(struct, [])

  defp format_parameters(changes) do
    new_changes =
      if is_nil(Map.get(changes, :parameters)) do
        Map.put(changes, :parameters, %{})
      else
        changes
      end

    new_parameters =
      Enum.reduce(Map.keys(new_changes), Map.new(), fn key, acc ->
        if not Enum.member?(@cast_fields, key) do
          Map.put(acc, key, new_changes[key])
        else
          acc
        end
      end)

    if new_parameters == %{} do
      new_changes
    else
      Map.put(new_changes, :parameters, new_parameters)
    end
  end

  defp validate_type(%{changes: %{type: type}} = changeset) do
    transformation_types = Options.transformations() |> Map.new() |> Map.keys()

    case type not in transformation_types do
      true -> Changeset.add_error(changeset, :type, "invalid type: #{type}")
      false -> changeset
    end
  end

  defp validate_type(changeset), do: changeset

  defp validate_parameters(changeset) do
    type =
      case Changeset.fetch_field(changeset, :type) do
        {_, ""} -> "invalid"
        {_, type} -> type
        :error -> "invalid"
      end

    parameters =
      case Changeset.fetch_field(changeset, :parameters) do
        {_, parameters} -> convert_parameters_from_atom_to_string(parameters)
        :error -> %{}
      end

    case Transformers.OperationBuilder.validate(type, parameters) do
      {:ok, _} ->
        changeset

      {:error, reason} when is_binary(reason) ->
        Changeset.add_error(changeset, :type, reason)

      {:error, reasons} ->
        Enum.reduce(reasons, changeset, fn {key, value}, changeset ->
          atom_key = String.to_atom(key)
          Changeset.add_error(changeset, atom_key, value)
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
end
