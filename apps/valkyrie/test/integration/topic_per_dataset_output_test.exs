defmodule Valkyrie.TopicPerDataset.OutputTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  @endpoints Application.get_env(:valkyrie, :elsa_brokers)
  @dlq_topic Application.get_env(:yeet, :topic)
  @input_topic_prefix Application.get_env(:valkyrie, :input_topic_prefix)
  @output_topic_prefix Application.get_env(:valkyrie, :output_topic_prefix)

  test "if handler can't immediately find the receiving topic, it retries up to its configured limit" do
    dataset_id = "missing_topic"
    input_topic = "#{@input_topic_prefix}-#{dataset_id}"
    output_topic = "#{@output_topic_prefix}-#{dataset_id}"

    dataset =
      TDG.create_dataset(
        id: dataset_id,
        technical: %{
          schema: [
            %{name: "name", type: "map", subSchema: [%{name: "first", type: "string"}, %{name: "last", type: "string"}]}
          ]
        }
      )

    original_message =
      TestHelpers.create_data(%{
        dataset_id: dataset.id,
        payload: %{name: %{first: "Ben", last: "Brewer"}}
      })

    SmartCity.Dataset.write(dataset)
    TestHelpers.wait_for_topic(input_topic)

    TestHelpers.produce_message(original_message, input_topic, @endpoints)
    Process.sleep(2_000)
    Elsa.Topic.create(@endpoints, output_topic)

    eventually fn ->
      messages = TestHelpers.get_data_messages_from_kafka(output_topic, @endpoints)

      assert original_message in messages
    end
  end

  test "if handler can't find the receiving topic, it DLQs the message after all retries" do
    dataset_id = "missing_topic_eternal"
    input_topic = "#{@input_topic_prefix}-#{dataset_id}"

    dataset =
      TDG.create_dataset(
        id: dataset_id,
        technical: %{
          schema: [
            %{name: "name", type: "map", subSchema: [%{name: "first", type: "string"}, %{name: "last", type: "string"}]}
          ]
        }
      )

    original_message =
      TestHelpers.create_data(%{
        dataset_id: dataset.id,
        payload: %{name: %{first: "Brian", last: "Balser"}}
      })

    encoded_og_message = Jason.encode!(original_message)

    SmartCity.Dataset.write(dataset)
    TestHelpers.wait_for_topic(input_topic)
    TestHelpers.produce_message(original_message, input_topic, @endpoints)

    eventually fn ->
      [message] = TestHelpers.get_dlq_messages_from_kafka(@dlq_topic, @endpoints)

      assert %{app: "Valkyrie", original_message: ^encoded_og_message} = message
    end
  end
end
