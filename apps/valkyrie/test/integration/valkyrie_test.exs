defmodule Valkyrie.FullTest do
  use ExUnit.Case
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0]

  alias Valkyrie.TopicHelper

  @endpoints Application.get_env(:valkyrie, :endpoints)

  setup_all do
    Logger.configure(level: :debug)
    dataset =
      TDG.create_dataset(%{
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
      TDG.create_data(%{
        payload: %{"name" => "Blackbeard", "alignment" => %{"invalid" => "string"}, "age" => "thirty-two"},
        dataset_id: dataset.id
      })

    messages = [
      TDG.create_data(%{
        payload: %{"name" => "Jack Sparrow", "alignment" => "chaotic", "age" => "32"},
        dataset_id: dataset.id
      }),
      invalid_message,
      TDG.create_data(%{
        payload: %{"name" => "Will Turner", "alignment" => "good", "age" => "25"},
        dataset_id: dataset.id
      }),
      TDG.create_data(%{
        payload: %{"name" => "Barbosa", "alignment" => "evil", "age" => "100"},
        dataset_id: dataset.id
      })
    ]

    input_topic = TopicHelper.input_topic_name(dataset.id)
    output_topic = TopicHelper.output_topic_name(dataset.id)

    Brook.Event.send(:valkyrie, data_ingest_start(), :valkyrie, dataset)
    Testing.Kafka.wait_for_topic(@endpoints, input_topic)
    Testing.Kafka.produce_messages(messages, input_topic, @endpoints)

    {:ok, %{output_topic: output_topic, messages: messages, invalid_message: invalid_message}}
  end

  # TODO - find a home for this
  # test "valkyrie updates the operational struct", %{output_topic: output_topic} do
  #   Application.put_env(:valkyrie, :profiling_enabled, true)
  #   eventually fn ->
  #     messages = Testing.Kafka.fetch_messages(output_topic, @endpoints)

  #     assert [%{operational: %{timing: [%{app: "valkyrie"} | _]}} | _] = messages
  #   end
  # end

  test "valkyrie processes messages, discarding those that cannot be standardized", %{
    output_topic: output_topic,
    messages: messages,
    invalid_message: invalid_message
  } do
    Application.put_env(:valkyrie, :profiling_enabled, false)
    eventually fn ->
      output_messages = Testing.SmartCity.Data.fetch_data_messages(output_topic, @endpoints)

      assert messages -- [invalid_message] == output_messages
    end
  end
end
