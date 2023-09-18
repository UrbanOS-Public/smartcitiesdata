defmodule Andi.InputSchemas.MessageCount do
  @moduledoc """
  Schema for event_logs
  """
  use Ecto.Schema
  use Properties, otp_app: :andi

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools

  @primary_key false
  schema "message_count" do
    field(:ingestion_id, Ecto.UUID, primary_key: true)
    field(:dataset_id, Ecto.UUID)
    field(:has_current_error, :boolean)
    field(:last_error_time, :utc_datetime, primary_key: true)

  end
  add(:dataset_id, :uuid, primary_key: true)
  add(:ingestion_id, :uuid, primary_key: true)
  add(:has_current_error, :boolean)
  add(:last_error_time, :utc_datetime, primary_key: true)
  use Accessible

  @cast_fields [
    :dataset_id,
    :ingestion_id,
    :has_current_error,
    :last_error_time
  ]

  @required_fields [
    :ingestion_id,
    :dataset_id,
    :last_error_time
  ]

  def changeset(%{} = changes) do
    changes_as_map = StructTools.to_map(changes)

    changeset(%__MODULE__{}, changes_as_map)
  end

  def changeset(%__MODULE__{} = message_count, %{} = changes) do
    message_count
    |> Changeset.cast(changes, @cast_fields, empty_values: [])
  end
end
