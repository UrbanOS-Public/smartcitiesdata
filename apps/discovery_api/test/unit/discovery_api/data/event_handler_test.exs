defmodule DiscoveryApi.EventListenerTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event, only: [organization_update: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias DiscoveryApi.EventHandler
  alias DiscoveryApi.Schemas.Organizations

  describe "handle_event/1" do
    test "should save organization to ecto" do
      org = TDG.create_organization(%{})
      allow(Organizations.create_or_update(any()), return: :dontcare)

      EventHandler.handle_event(Brook.Event.new(type: organization_update(), data: org, author: :author))

      assert_called(Organizations.create_or_update(org))
    end
  end
end
