defmodule DiscoveryApi.Schemas.Users.UserOrganization do
  @moduledoc """
  Ecto schema respresentation of the User-Organization association.
  """

  use Ecto.Schema
  alias DiscoveryApi.Schemas.Users.User
  alias DiscoveryApi.Schemas.Organizations.Organization

  @primary_key false

  schema "user_organizations" do
    belongs_to(:user, User, type: Ecto.UUID, primary_key: true)
    belongs_to(:organization, Organization, type: :string, primary_key: true)

    timestamps()
  end
end
