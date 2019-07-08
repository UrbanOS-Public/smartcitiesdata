defmodule Reaper.DataFeed.SchemaStageTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.DataFeed.SchemaStage

  describe "handle_events/3" do
    setup do
      nested_maps_schema = [
        %{name: "id", type: "string"},
        %{
          name: "grandParent",
          type: "map",
          subSchema: [
            %{name: "uncle", type: "string"},
            %{
              name: "parent",
              type: "list",
              itemType: "map",
              subSchema: [%{name: "childName", type: "string"}, %{name: "color", type: "string"}]
            }
          ]
        }
      ]

      [
        schema: nested_maps_schema
      ]
    end

    test "allows fully populated records to pass through", %{schema: schema} do
      incoming_events = [
        {%{
           "id" => "123",
           "grandParent" => %{
             "uncle" => "bob",
             "parent" => [%{"childName" => "Joe", "color" => "Fred"}]
           }
         }, 1},
        {%{
           "id" => "123",
           "grandParent" => %{
             "uncle" => "jimbo",
             "parent" => [%{"childName" => "frank", "color" => "green"}]
           }
         }, 2}
      ]

      state = %{
        config: FixtureHelper.new_reaper_config(%{dataset_id: "ds1", schema: schema})
      }

      {:noreply, outgoing_events, _new_state} = SchemaStage.handle_events(incoming_events, self(), state)

      assert outgoing_events == incoming_events
    end

    test "Fills empty payloads with schema appropriate nils", %{schema: schema} do
      incoming_events = [
        {%{
           "id" => "456",
           "grandParent" => %{}
         }, 1},
        {%{
           "grandParent" => %{"uncle" => "bill", "parent" => [%{"childName" => "jim"}, %{"color" => "blue"}]}
         }, 2}
      ]

      expected = [
        {%{
           "id" => "456",
           "grandParent" => %{
             "uncle" => nil,
             "parent" => []
           }
         }, 1},
        {%{
           "id" => nil,
           "grandParent" => %{
             "uncle" => "bill",
             "parent" => [%{"childName" => "jim", "color" => nil}, %{"childName" => nil, "color" => "blue"}]
           }
         }, 2}
      ]

      state = %{
        config: FixtureHelper.new_reaper_config(%{dataset_id: "ds1", schema: schema})
      }

      {:noreply, outgoing_events, _new_state} = SchemaStage.handle_events(incoming_events, self(), state)

      assert outgoing_events == expected
    end
  end
end
