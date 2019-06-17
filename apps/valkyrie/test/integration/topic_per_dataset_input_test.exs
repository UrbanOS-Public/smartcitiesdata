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
        technical: %{schema: [%{name: "key", type: "string"}]}
      )

    input_topic = "#{@input_topic_prefix}-#{dataset.id}"

    SmartCity.Dataset.write(dataset)

    eventually fn ->
      assert Valkyrie.TopicManager.is_topic_ready?(input_topic)
    end
  end

  test "handler reads incoming topic, validates, and writes to outgoing topic" do
    dataset =
      TDG.create_dataset(
        id: "somevalue",
        technical: %{
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

    SmartCity.Dataset.write(dataset)
    TestHelpers.wait_for_topic(input_topic)
    Elsa.Topic.create(@endpoints, output_topic)

    original_message =
      TestHelpers.create_data(%{
        dataset_id: dataset.id,
        payload: %{name: %{first: "Jeff", last: "Grunewald"}}
      })

    TestHelpers.produce_message(original_message, input_topic, @endpoints)

    eventually fn ->
      messages = TestHelpers.get_data_messages_from_kafka(output_topic, @endpoints)

      assert original_message in messages
    end
  end
end
