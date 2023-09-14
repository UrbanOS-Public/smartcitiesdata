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
    field(:actual_message_count, :integer)
    field(:expected_message_count, :integer)
    field(:extraction_start_time, :utc_datetime, primary_key: true)
    field(:ingestion_id, Ecto.UUID, primary_key: true)
    field(:dataset_id, Ecto.UUID)
  end

  use Accessible

  @cast_fields [
    :actual_message_count,
    :expected_message_count,
    :extraction_start_time,
    :ingestion_id,
    :dataset_id
  ]

  @required_fields [
    :extraction_start_time,
    :dataset_id
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
