defmodule Andi.InputSchemas.MessageError do
  @moduledoc """
  Schema for event_logs
  """
  use Ecto.Schema
  use Properties, otp_app: :andi

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools

  @primary_key false
  schema "message_error" do
    field(:ingestion_id, Ecto.UUID)
    field(:dataset_id, Ecto.UUID, primary_key: true)
    field(:has_current_error, :boolean)
    field(:last_error_time, :utc_datetime)
  end

  use Accessible

  @cast_fields [
    :ingestion_id,
    :dataset_id,
    :has_current_error,
    :last_error_time
  ]

  @required_fields [
    :dataset_id
  ]

  def changeset(%{} = changes) do
    changes_as_map = StructTools.to_map(changes)

    changeset(%__MODULE__{}, changes_as_map)
  end

  def changeset(%__MODULE__{} = message_error, %{} = changes) do
    message_error
    |> Changeset.cast(changes, @cast_fields, empty_values: [])
  end
end
