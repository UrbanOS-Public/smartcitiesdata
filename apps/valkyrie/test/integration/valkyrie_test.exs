defmodule ValkyrieTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  @endpoints Application.get_env(:valkyrie, :elsa_brokers)
  @dlq_topic Application.get_env(:yeet, :topic)
  @input_topic_prefix Application.get_env(:valkyrie, :input_topic_prefix)
  @output_topic_prefix Application.get_env(:valkyrie, :output_topic_prefix)

  setup_all do
    dataset =
      TDG.create_dataset(%{
        id: "pirates",
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string"},
            %{name: "alignment", type: "string"},
            %{name: "age", type: "string"}
          ]
        }
      })

    invalid_message =
      TestHelpers.create_data(%{
        payload: %{"name" => "Blackbeard", "alignment" => %{"invalid" => "string"}, "age" => "thirty-two"},
        dataset_id: dataset.id
      })

    messages = [
      TestHelpers.create_data(%{
        payload: %{"name" => "Jack Sparrow", "alignment" => "chaotic", "age" => "32"},
        dataset_id: dataset.id
      }),
      invalid_message,
      TestHelpers.create_data(%{
        payload: %{"name" => "Will Turner", "alignment" => "good", "age" => "25"},
        dataset_id: dataset.id
      }),
      TestHelpers.create_data(%{
        payload: %{"name" => "Barbosa", "alignment" => "evil", "age" => "100"},
        dataset_id: dataset.id
      })
    ]

    input_topic = "#{@input_topic_prefix}-#{dataset.id}"
    output_topic = "#{@output_topic_prefix}-#{dataset.id}"

    SmartCity.Dataset.write(dataset)
    TestHelpers.wait_for_topic(@endpoints, input_topic)
    Elsa.Topic.create(@endpoints, output_topic)

    TestHelpers.produce_messages(messages, input_topic, @endpoints)

    {:ok, %{output_topic: output_topic, messages: messages, invalid_message: invalid_message}}
  end

  test "valkyrie updates the operational struct", %{output_topic: output_topic} do
    eventually fn ->
      messages = TestHelpers.get_data_messages_from_kafka_with_timing(output_topic, @endpoints)

      assert [%{operational: %{timing: [%{app: "valkyrie"} | _]}} | _] = messages
    end
  end

  test "valkyrie rejects unparseable messages and passes the rest through", %{
    output_topic: output_topic,
    messages: messages,
    invalid_message: invalid_message
  } do
    eventually fn ->
      output_messages = TestHelpers.get_data_messages_from_kafka(output_topic, @endpoints)

      assert messages -- [invalid_message] == output_messages
    end
  end

  test "valkyrie sends invalid data messages to the dlq", %{invalid_message: invalid_message} do
    encoded_og_message = invalid_message |> Jason.encode!()

    eventually fn ->
      messages = TestHelpers.get_dlq_messages_from_kafka(@dlq_topic, @endpoints)

      assert [%{app: "Valkyrie", original_message: ^encoded_og_message}] = messages
    end
  end
end
