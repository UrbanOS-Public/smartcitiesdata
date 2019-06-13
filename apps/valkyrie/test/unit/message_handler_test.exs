defmodule Valkyrie.MessageHandlerTest do
  use ExUnit.Case
  use Placebo

  @moduletag capture_log: true

  describe "handle_messages/1" do
    test "produces valid message to kafka" do
      expected_message =
        "{\"_metadata\":{},\"dataset_id\":\"basic\",\"operational\":{\"timing\":[{\"app\":\"valkyrie\",\"end_time\":\"2019-04-17T19:50:06.455498Z\",\"label\":\"timing\",\"start_time\":\"2019-04-17T19:50:06.455498Z\"}]},\"payload\":{\"name\":\"Jack Sparrow\"},\"version\":\"0.1\"}"

      messages = [
        %{
          key: "someKey",
          value: %{
            payload: %{name: "Jack Sparrow"},
            operational: %{timing: []},
            dataset_id: "basic",
            _metadata: %{}
          }
        }
      ]

      allow Yeet.process_dead_letter("unknown", any(), any(), any()), return: :does_not_matter
      allow Elsa.Topic.list(any()), return: [{"unit-basic", 1}]
      allow Elsa.Producer.produce_sync(any(), any(), any(), any(), any()), return: :ok
      allow SmartCity.Data.Timing.current_time(), return: "2019-04-17T19:50:06.455498Z", meck_options: [:passthrough]
      allow Valkyrie.Dataset.get("basic"), return: %Valkyrie.Dataset{schema: [%{name: "name", type: "string"}]}

      Valkyrie.MessageHandler.handle_messages(messages)

      assert_called Elsa.Producer.produce_sync(any(), "unit-basic", 0, "someKey", expected_message)
      refute_called Yeet.process_dead_letter("unknown", any(), any(), any())
    end

    test "invalid messages are yeeted" do
      messages = [
        %{
          key: "someKey",
          value: %{
            payload: %{name: "Jack Sparrow", age: nil},
            operational: %{timing: []},
            dataset_id: "basic",
            _metadata: %{}
          }
        }
      ]

      allow Yeet.process_dead_letter("unknown", any(), any(), any()), return: :does_not_matter
      allow Elsa.Topic.list(any()), return: []
      allow Elsa.Producer.produce_sync(any(), any(), any(), any(), any()), return: :does_not_matter
      allow SmartCity.Data.Timing.current_time(), return: "2019-04-17T19:50:06.455498Z", meck_options: [:passthrough]

      allow Valkyrie.Dataset.get("basic"),
        return: %Valkyrie.Dataset{
          schema: [
            %{name: "name", type: "string"},
            %{name: "age", type: "string", required: true},
            %{name: "weight", type: "string", required: true},
            %{name: "height", type: "string", required: true}
          ]
        }

      Valkyrie.MessageHandler.handle_messages(messages)

      refute_called Elsa.Producer.produce_sync(any(), any(), any(), any(), any())

      assert_called Yeet.process_dead_letter("unknown", any(), any(),
                      reason: "\"The following fields were invalid: weight, height\""
                    )
    end
  end
end
