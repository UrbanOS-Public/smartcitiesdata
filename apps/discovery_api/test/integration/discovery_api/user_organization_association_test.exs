defmodule DiscoveryApi.UserOrganizationAssociationTest do
  use ExUnit.Case
  use DiscoveryApi.DataCase
  import SmartCity.Event, only: [user_organization_associate: 0]
  import SmartCity.TestHelper
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User

  test "when a user:organization:associate event is received then the association is persisted" do
    organization = Helper.create_persisted_organization()
    {:ok, user} = Users.create_or_update("unique|id", %{email: "thing@thing.thing"})

    {:ok, association_event} = SmartCity.UserOrganizationAssociate.new(%{user_id: user.id, org_id: organization.id})

    Brook.Event.send(DiscoveryApi.instance_name(), user_organization_associate(), __MODULE__, association_event)

    eventually(
      fn ->
        assert {:ok, %User{organizations: [associated_org]}} = Users.get_user_with_organizations(user.id)
        assert organization.id == associated_org.id
      end,
      500,
      10
    )
  end
end
