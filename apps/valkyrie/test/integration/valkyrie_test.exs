defmodule ValkyrieTest do
  use ExUnit.Case
  use Divo
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_ingest_start: 0]

  @endpoints Application.get_env(:valkyrie, :elsa_brokers)
  @dlq_topic Application.get_env(:dead_letter, :driver) |> get_in([:init_args, :topic])
  @input_topic_prefix Application.get_env(:valkyrie, :input_topic_prefix)
  @output_topic_prefix Application.get_env(:valkyrie, :output_topic_prefix)
  @instance Valkyrie.Application.instance()

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

    Brook.Event.send(@instance, data_ingest_start(), :valkyrie, dataset)
    TestHelpers.wait_for_topic(@endpoints, input_topic)

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

    metrics_port = Application.get_env(:telemetry_event, :metrics_port)

    eventually fn ->
      messages = TestHelpers.get_dlq_messages_from_kafka(@dlq_topic, @endpoints)

      assert :ok =
               [
                 dataset_id: "dataset_id",
                 reason: "reason"
               ]
               |> TelemetryEvent.add_event_count([:dead_letters_handled])

      response = HTTPoison.get!("http://localhost:#{metrics_port}/metrics")

      assert response.body ==
               "# HELP dead_letters_handled_count \n# TYPE dead_letters_handled_count counter\ndead_letters_handled_count{dataset_id=\"dataset_id\",reason=\"reason\"} 7\ndead_letters_handled_count{dataset_id=\"pirates\",reason=\"%{\\\"alignment\\\" => :invalid_string}\"} 1\n# HELP events_handled_count \n# TYPE events_handled_count counter\nevents_handled_count{app=\"valkyrie\",author=\"valkyrie\",dataset_id=\"pirates\",event_type=\"data:ingest:start\"} 1\n"

      assert [%{app: "Valkyrie", original_message: ^encoded_og_message}] = messages
    end
  end
end
