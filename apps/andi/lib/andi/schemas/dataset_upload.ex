defmodule Andi.Schemas.DatasetUpload do
  @moduledoc """
  Module representing a dataset upload request in postgres
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "dataset_upload" do
    field(:dataset_id, Ecto.UUID)
    field(:timestamp, :utc_datetime)
    field(:user_uploading, :string)
    field(:upload_success, :boolean)
    field(:dataset_link, :string)
  end

  use Accessible

  @cast_fields [
    :dataset_id,
    :timestamp,
    :user_uploading,
    :upload_success,
    :dataset_link
  ]

  def changeset(changes), do: changeset(%__MODULE__{}, changes)

  def changeset(dataset_upload, changes) do
    changes_with_id = StructTools.ensure_id(dataset_upload, changes)

    dataset_upload
    |> cast(changes_with_id, @cast_fields, empty_values: [])
  end
end
