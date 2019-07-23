defmodule Valkyrie.TopicPerDataset.InputTest do
  use ExUnit.Case
  use Divo

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  @endpoints Application.get_env(:valkyrie, :elsa_brokers)
  @input_topic_prefix Application.get_env(:valkyrie, :input_topic_prefix)
  @output_topic_prefix Application.get_env(:valkyrie, :output_topic_prefix)

  test "handler creates new topic on dataset message" do
    dataset =
      TDG.create_dataset(
        id: "topic-create-test",
        technical: %{schema: [%{name: "key", type: "string"}], sourceType: "ingest"}
      )

    input_topic = "#{@input_topic_prefix}-#{dataset.id}"
    output_topic = "#{@output_topic_prefix}-#{dataset.id}"

    Elsa.Topic.create(@endpoints, output_topic)
    SmartCity.Dataset.write(dataset)

    eventually fn ->
      assert Elsa.topic?(@endpoints, input_topic)
    end
  end

  test "handler reads incoming topic, validates, and writes to outgoing topic" do
    dataset =
      TDG.create_dataset(
        id: "somevalue",
        technical: %{
          sourceType: "ingest",
          schema: [
            %{
              name: "name",
              type: "map",
              subSchema: [%{name: "first", type: "string"}, %{name: "last", type: "string"}]
            }
          ]
        }
      )

    output_topic = "#{@output_topic_prefix}-#{dataset.id}"
    input_topic = "#{@input_topic_prefix}-#{dataset.id}"

    Elsa.Topic.create(@endpoints, output_topic)
    SmartCity.Dataset.write(dataset)
    TestHelpers.wait_for_topic(@endpoints, input_topic)

    original_message =
      TestHelpers.create_data(%{
        dataset_id: dataset.id,
        payload: %{"name" => %{"first" => "Jeff", "last" => "Grunewald"}}
      })

    TestHelpers.produce_message(original_message, input_topic, @endpoints)

    eventually fn ->
                 messages = TestHelpers.get_data_messages_from_kafka(output_topic, @endpoints)

                 assert original_message in messages
               end,
               2000,
               20
  end
end
