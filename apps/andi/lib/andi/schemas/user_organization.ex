defmodule Andi.Schemas.UserOrganization do
  @moduledoc """
  Ecto schema respresentation of the User-Organization association.
  """

  use Ecto.Schema
  alias Andi.Schemas.User
  alias Andi.InputSchemas.Organization

  @primary_key false

  schema "user_organizations" do
    belongs_to(:user, User, type: Ecto.UUID, primary_key: true)
    belongs_to(:organization, Organization, type: Ecto.UUID, primary_key: true)

    timestamps()
  end
end
