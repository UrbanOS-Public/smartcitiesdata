defmodule Andi.Schemas.AuditEvent do
  @moduledoc """
  Module representing an audit_event request in postgres
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "audit_events" do
    field(:user_id, :string)
    field(:event_type, :string)
    field(:event, :map)
    timestamps()
  end

  use Accessible

  @cast_fields [
    :id,
    :user_id,
    :event_type,
    :event
  ]

  @required_fields [
    :id,
    :user_id,
    :event_type,
    :event
  ]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(audit_event, changes) do
    changes_with_id = StructTools.ensure_id(audit_event, changes)

    audit_event
    |> cast(changes_with_id, @cast_fields, empty_values: [])
    |> validate_required(@required_fields, message: "is required")
  end
end
