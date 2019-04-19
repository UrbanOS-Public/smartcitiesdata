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
            "payload" => %{"name" => "Jack Sparrow"},
            "operational" => %{"timing" => []},
            "dataset_id" => "basic",
            "_metadata" => %{}
          }
        }
      ]

      allow Yeet.process_dead_letter(any(), any(), any()), return: :does_not_matter
      allow Kaffe.Producer.produce_sync(any(), any()), return: :does_not_matter
      allow SmartCity.Data.Timing.current_time(), return: "2019-04-17T19:50:06.455498Z", meck_options: [:passthrough]
      allow Valkyrie.Dataset.get("basic"), return: %{schema: [%{"name" => "name", "type" => "string"}]}

      Valkyrie.MessageHandler.handle_messages(messages)

      assert_called Kaffe.Producer.produce_sync("someKey", expected_message)
      assert_called Yeet.process_dead_letter(any(), any(), any()), times(0)
    end
  end
end
