defmodule Andi.Schemas.UserAccessGroup do
  @moduledoc """
  Ecto schema respresentation of the User-Access Group association.
  """

  use Ecto.Schema
  alias Andi.Schemas.User
  alias Andi.InputSchemas.AccessGroup

  @primary_key false

  schema "user_access_groups" do
    belongs_to(:user, User, type: Ecto.UUID, primary_key: true)
    belongs_to(:access_group, AccessGroup, type: Ecto.UUID, primary_key: true)

    timestamps()
  end
end
