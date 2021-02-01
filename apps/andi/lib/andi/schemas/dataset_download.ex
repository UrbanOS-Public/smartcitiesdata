defmodule Andi.Schemas.DatasetDownload do
  @moduledoc """
  Module representing a dataset download request in postgres
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Andi.InputSchemas.StructTools

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "dataset_download" do
    field(:dataset_id, Ecto.UUID)
    field(:dataset_link, :string)
    field(:request_headers, :string)
    field(:timestamp, :utc_datetime)
    field(:user_accessing, :string)
    field(:download_success, :boolean)
  end

  use Accessible

  @cast_fields [
    :dataset_id,
    :dataset_link,
    :request_headers,
    :timestamp,
    :user_accessing,
    :download_success
  ]

  def changeset(dataset_download, changes) do
    changes_with_id = StructTools.ensure_id(dataset_download, changes)

    dataset_download
    |> cast(changes_with_id, @cast_fields, empty_values: [])
  end
end
