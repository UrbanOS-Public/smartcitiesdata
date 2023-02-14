defmodule Andi.InputSchemas.Ingestions.ExtractStep do
  @moduledoc """
  Generic schema for all types of extract steps. The `context` field is validated differently based on the type of step

  """
  use Ecto.Schema

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Ingestion

  @cast_fields [:id, :context, :type, :sequence, :ingestion_id]
  @required_fields [:type, :context]

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "extract_step" do
    field(:type, :string)
    field(:context, :map)
    field(:sequence, :integer, read_after_writes: true)
    belongs_to(:ingestion, Ingestion, type: Ecto.UUID, foreign_key: :ingestion_id)
  end

  use Accessible

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> Changeset.cast(changes_with_id, @cast_fields, force_changes: true)
  end

  def validate(extract_step_changeset) do
    data_as_changes =
      extract_step_changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()

    extract_step_changeset
      |> Map.replace(:errors, [])
      |> Changeset.cast(data_as_changes, @cast_fields, empty_values: [], force_changes: true)
      |> Changeset.validate_required(@required_fields, message: "is required")
      |> validate_type()
      |> validate_context()
  end

  def changeset_for_draft(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> Changeset.cast(changes_with_id, @cast_fields, force_changes: true)
  end

  def changeset_from_form_data(form_data) do
    form_data_as_params =
      form_data
      |> AtomicMap.convert(safe: false, underscore: false)
      |> wrap_context()

    changeset(form_data_as_params)
  end

  def form_changeset_from_andi_extract_step(%{type: "sftp", context: context}), do: context

  def form_changeset_from_andi_extract_step(extract_step) do
    step_module = step_module(extract_step.type)

    changes =
      extract_step
      |> StructTools.to_map()
      |> Map.get(:context)

    step_module.changeset(step_module.get_module(), changes)
  end

  def create_step_changeset_from_generic_step_changeset(changeset) do
    {_, type} = Changeset.fetch_field(changeset, :type)

    step_module = step_module(type)

    {:ok, changes} = Changeset.fetch_change(changeset, :context)
      |> StructTools.to_map()

    step_module.changeset(step_module.get_module(), changes)
      |> step_module.validate()
  end

  def preload(struct), do: StructTools.preload(struct, [])

  defp validate_type(%{changes: %{type: type}} = changeset) do
    case step_module(type) == :invalid_type do
      true -> Changeset.add_error(changeset, :type, "invalid type")
      false -> changeset
    end
  end

  defp validate_type(changeset), do: changeset

  defp validate_context(changeset) do
    type =
      case Changeset.fetch_field(changeset, :type) do
        {_, type} -> type
        :error -> nil
      end

    case step_module(type) do
      :invalid_type -> changeset
      nil -> changeset

      step_module ->
        context =
          case Changeset.fetch_field(changeset, :context) do
            {_, context} -> context
            :error -> nil
          end
        validated_changeset = step_module.changeset(step_module.get_module(), context)
          |> step_module.validate()

        Enum.reduce(validated_changeset.errors, changeset, fn {key, {message, _}}, acc ->
          Changeset.add_error(acc, key, message)
        end)
    end
  end

  def step_module("http"), do: Andi.InputSchemas.Ingestions.ExtractHttpStep
  def step_module("date"), do: Andi.InputSchemas.Ingestions.ExtractDateStep
  def step_module("secret"), do: Andi.InputSchemas.Ingestions.ExtractSecretStep
  def step_module("auth"), do: Andi.InputSchemas.Ingestions.ExtractAuthStep
  def step_module("s3"), do: Andi.InputSchemas.Ingestions.ExtractS3Step
  def step_module("sftp"), do: nil
  def step_module(_invalid_type), do: :invalid_type

  defp wrap_context(form_data) do
    context =
      form_data
      |> Map.delete(:type)

    %{type: form_data.type, context: context}
  end
end
