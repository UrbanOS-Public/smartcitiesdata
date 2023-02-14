defmodule Andi.InputSchemas.Ingestions.ExtractSecretStep do
  @moduledoc false
  use Ecto.Schema

  alias Andi.InputSchemas.StructTools
  alias Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:destination, :string)
    field(:key, :string)
    field(:sub_key, :string)
  end

  use Accessible

  @fields [:destination, :key, :sub_key]

  def get_module(), do: %__MODULE__{}

  def changeset(extract_step, changes) do
    changes_with_id = StructTools.ensure_id(extract_step, changes)
      |> AtomicMap.convert(safe: false, underscore: false)

    extract_step
    |> Changeset.cast(changes_with_id, @fields, empty_values: [])
  end

  def validate(extract_step_changeset) do
    data_as_changes =
      extract_step_changeset
      |> Changeset.apply_changes()
      |> StructTools.to_map()

    validated_extract_step_changeset = extract_step_changeset
      |> Map.replace(:errors, [])
      |> Changeset.cast(data_as_changes, @fields, force_changes: true)
      |> Changeset.validate_required(@fields, message: "is required")
      |> Changeset.validate_format(:destination, ~r/^[[:alpha:]_]+$/)

    if is_nil(Map.get(validated_extract_step_changeset, :action, nil)) do
      Map.put(validated_extract_step_changeset, :action, :display_errors)
    else
      validated_extract_step_changeset
    end
  end
end
