defmodule Raptor.Event.EventHandlerTest do
  use ExUnit.Case

  import SmartCity.TestHelper

  import SmartCity.Event,
    only: [dataset_update: 0, user_organization_disassociate: 0, user_login: 0]

  alias SmartCity.TestDataGenerator, as: TDG
  alias Raptor.Test.Helper

  @instance_name Raptor.instance_name()

  describe "organization:update" do
    test "when an organization is updated then it is retrievable" do
      organization = TDG.create_organization(%{})
      Brook.Event.send(@instance_name, "organization:update", :test, organization)

      # Currently, this test is just a shell that demonstrates how to stand up an integration test and send a Brook event
      # TODO: Once the event handler has functionality beyond discarding the event, update this test to the expected behavior
    end
  end
end
