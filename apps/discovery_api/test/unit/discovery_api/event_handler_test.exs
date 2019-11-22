defmodule DiscoveryApi.EventHandlerTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event, only: [organization_update: 0, user_organization_associate: 0]
  import ExUnit.CaptureLog

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.EventHandler
  alias DiscoveryApi.Schemas.Organizations
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User

  describe "handle_event/1 organization_update" do
    test "should save organization to ecto" do
      org = TDG.create_organization(%{})
      allow Organizations.create_or_update(any()), return: :dontcare

      EventHandler.handle_event(Brook.Event.new(type: organization_update(), data: org, author: :author))

      assert_called(Organizations.create_or_update(org))
    end
  end

  describe "handle_event/1 user_organization_associate" do
    setup do
      {:ok, association_event} = SmartCity.UserOrganizationAssociate.new(%{user_id: "user_id", org_id: "org_id"})

      %{association_event: association_event}
    end

    test "should save user/organization association to ecto", %{association_event: association_event} do
      allow Users.associate_with_organization(any(), any()), return: {:ok, %User{}}

      EventHandler.handle_event(Brook.Event.new(type: user_organization_associate(), data: association_event, author: :author))

      assert_called(Users.associate_with_organization(association_event.user_id, association_event.org_id))
    end

    test "logs errors when save fails", %{association_event: association_event} do
      error_message = "you're a huge embarrassing failure"
      allow Users.associate_with_organization(any(), any()), return: {:error, error_message}

      assert capture_log(fn ->
               EventHandler.handle_event(Brook.Event.new(type: user_organization_associate(), data: association_event, author: :author))
             end) =~ error_message
    end
  end
end
