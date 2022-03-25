defmodule Andi.Schemas.DatasetAccessGroup do
  @moduledoc """
  Ecto schema respresentation of the Dataset-Access Group association.
  """

  use Ecto.Schema
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Datasets.Dataset

  @primary_key false

  schema "dataset_access_groups" do
    belongs_to(:access_group, AccessGroup, type: Ecto.UUID, primary_key: true)
    belongs_to(:dataset, Dataset, type: :string, primary_key: true)

    timestamps()
  end
end
