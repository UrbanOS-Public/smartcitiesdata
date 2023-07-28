defmodule Andi.InputSchemas.EventLog do
  @moduledoc """
  Schema for event_logs
  """
  use Ecto.Schema
  use Properties, otp_app: :andi

  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "event_log" do
    field(:title, :string)
    field(:timestamp, :utc_datetime)
    field(:source, :string)
    field(:description, :string)
    field(:ingestion_id, Ecto.UUID)
    field(:dataset_id, Ecto.UUID)
  end

  use Accessible

  @cast_fields [
    :title,
    :timestamp,
    :source,
    :description,
    :ingestion_id,
    :dataset_id
  ]

  @required_fields [
    :title,
    :timestamp,
    :source,
    :description
  ]

  def changeset(%SmartCity.EventLog{} = changes) do
    changes_as_map = StructTools.to_map(changes)

    changeset(%__MODULE__{}, changes_as_map)
  end

  def changeset(%__MODULE__{} = event_log, %{} = changes) do
    event_log
    |> Changeset.cast(changes, @cast_fields, empty_values: [])
  end
end
