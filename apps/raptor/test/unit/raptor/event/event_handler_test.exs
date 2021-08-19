defmodule Raptor.Event.EventHandlerTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event,
    only: [
      organization_update: 0,
      user_organization_associate: 0,
      user_organization_disassociate: 0
    ]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Raptor.Event.EventHandler

  describe "handle_event/1 organization_update" do
    test "should return :discard when an event is received" do
      org = TDG.create_organization(%{})

      result =
        EventHandler.handle_event(
          Brook.Event.new(type: organization_update(), data: org, author: :author)
        )

      assert result == :discard
    end
  end

  describe "handle_event/1 user_organization_associate" do
    setup do
      {:ok, association_event} =
        SmartCity.UserOrganizationAssociate.new(%{
          subject_id: "user_id",
          org_id: "org_id",
          email: "bob@example.com"
        })

      %{association_event: association_event}
    end

    test "should return :discard when an event is received", %{
      association_event: association_event
    } do
      result =
        EventHandler.handle_event(
          Brook.Event.new(
            type: user_organization_associate(),
            data: association_event,
            author: :author
          )
        )

      assert result == :discard
    end
  end

  describe "handle_event/1 user_organization_disassociate" do
    setup do
      {:ok, disassociation_event} =
        SmartCity.UserOrganizationDisassociate.new(%{subject_id: "subject_id", org_id: "org_id"})

      %{disassociation_event: disassociation_event}
    end

    test "should return :discard when an event is received", %{
      disassociation_event: disassociation_event
    } do
      result =
        EventHandler.handle_event(
          Brook.Event.new(
            type: user_organization_disassociate(),
            data: disassociation_event,
            author: :author
          )
        )

      assert result == :discard
    end
  end
end
