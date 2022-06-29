defmodule Andi.InputSchemas.Ingestions.ExtractStep do
  @moduledoc """
  Generic schema for all types of extract steps. The `context` field is validated differently based on the type of step

  """
  use Ecto.Schema
  import Ecto.Changeset
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
    |> cast(changes_with_id, @cast_fields)
    |> validate_required(@required_fields, message: "is required")
    |> validate_type()
    |> validate_context()
  end

  def changeset_for_draft(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)

    extract_step
    |> cast(changes_with_id, @cast_fields)
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

    extract_step
    |> Andi.InputSchemas.StructTools.to_map()
    |> Map.get(:context)
    |> step_module.changeset_from_andi_step()
  end

  def preload(struct), do: StructTools.preload(struct, [])

  defp validate_type(%{changes: %{type: type}} = changeset) do
    case step_module(type) == :invalid_type do
      true -> add_error(changeset, :type, "invalid type")
      false -> changeset
    end
  end

  defp validate_context(%{changes: %{context: nil}} = changeset), do: changeset

  defp validate_context(%{changes: %{type: type, context: context}} = changeset) do
    case step_module(type) do
      :invalid_type ->
        changeset

      nil ->
        changeset

      step_module ->
        validated_context = step_module.changeset(context)

        updated_changeset =
          Enum.reduce(validated_context.errors, changeset, fn {key, {message, _}}, acc ->
            Ecto.Changeset.add_error(acc, key, message)
          end)

        updated_changeset
    end
  end

  defp validate_context(changeset), do: changeset

  defp step_module("http"), do: Andi.InputSchemas.Ingestions.ExtractHttpStep
  defp step_module("date"), do: Andi.InputSchemas.Ingestions.ExtractDateStep
  defp step_module("secret"), do: Andi.InputSchemas.Ingestions.ExtractSecretStep
  defp step_module("auth"), do: Andi.InputSchemas.Ingestions.ExtractAuthStep
  defp step_module("s3"), do: Andi.InputSchemas.Ingestions.ExtractS3Step
  defp step_module("sftp"), do: nil
  defp step_module(_invalid_type), do: :invalid_type

  defp wrap_context(form_data) do
    context =
      form_data
      |> Map.delete(:type)

    %{type: form_data.type, context: context}
  end
end
