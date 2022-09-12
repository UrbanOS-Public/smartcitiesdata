defmodule AlchemistTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :alchemist

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  import SmartCity.Event,
    only: [ingestion_update: 0]

  alias TelemetryEvent.Helper.TelemetryEventHelper

  @instance_name Alchemist.instance_name()
  # @dlq_topic Application.get_env(:dead_letter, :driver) |> get_in([:init_args, :topic])

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

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

    ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})

    pid = start_telemetry()

    on_exit(fn ->
      stop_telemetry(pid)
    end)

    pre_transform_messages = [
      TestHelpers.create_data(%{
        payload: %{"name" => "Jack Sparrow", "alignment" => "chaotic", "age" => "32"},
        dataset_id: dataset.id
      }),
      TestHelpers.create_data(%{
        payload: %{"name" => "Will Turner", "alignment" => "good", "age" => "25"},
        dataset_id: dataset.id
      }),
      TestHelpers.create_data(%{
        payload: %{"name" => "Barbosa", "alignment" => "evil", "age" => "100"},
        dataset_id: dataset.id
      })
    ]

    input_topic = "#{input_topic_prefix()}-#{ingestion.id}"
    output_topic = "#{output_topic_prefix()}-#{dataset.id}"

    Brook.Event.send(@instance_name, ingestion_update(), :alchemist, ingestion)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)

    TestHelpers.produce_messages(pre_transform_messages, input_topic, elsa_brokers())

    {:ok, %{output_topic: output_topic, pre_transform_messages: pre_transform_messages, dataset: dataset}}
  end

  test "alchemist updates the operational struct", %{
    output_topic: output_topic,
    pre_transform_messages: pre_transform_messages
  } do
    eventually fn ->
      post_transform_messages = TestHelpers.get_data_messages_from_kafka_with_timing(output_topic, elsa_brokers())

      assert pre_transform_messages == post_transform_messages
    end
  end

  test "alchemist only starts the processes for ingest once on event handle", %{
    pre_transform_messages: pre_transform_messages
  } do
    dataset =
      TDG.create_dataset(%{
        id: "pirates2",
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string"},
            %{name: "alignment", type: "string"},
            %{name: "age", type: "string"}
          ]
        }
      })

    ingestion = TDG.create_ingestion(%{targetDataset: dataset.id})

    pre_transform_messages =
      Enum.map(pre_transform_messages, fn message -> Map.put(message, :dataset_id, dataset.id) end)

    input_topic = "#{input_topic_prefix()}-#{ingestion.id}"
    output_topic = "#{output_topic_prefix()}-#{dataset.id}"

    Brook.Event.send(@instance_name, ingestion_update(), :alchemist, ingestion)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)

    1..100
    |> Enum.each(fn _ ->
      Brook.Event.send(@instance_name, ingestion_update(), :alchemist, ingestion)
    end)

    TestHelpers.produce_messages(pre_transform_messages, input_topic, elsa_brokers())

    eventually fn ->
      post_transform_messages = TestHelpers.get_data_messages_from_kafka_with_timing(output_topic, elsa_brokers())

      assert pre_transform_messages == post_transform_messages
    end
  end

  # test "alchemist sends invalid data messages to the dlq", %{invalid_message: invalid_message} do
  #   encoded_og_message = invalid_message |> Jason.encode!()

  #   metrics_port = Application.get_env(:telemetry_event, :metrics_port)

  #   eventually fn ->
  #     messages = TestHelpers.get_dlq_messages_from_kafka(@dlq_topic, elsa_brokers())

  #     assert :ok =
  #              [
  #                dataset_id: "dataset_id",
  #                reason: "reason"
  #              ]
  #              |> TelemetryEvent.add_event_metrics([:dead_letters_handled])

  #     response = HTTPoison.get!("http://localhost:#{metrics_port}/metrics")

  #     assert true ==
  #              String.contains?(
  #                response.body,
  #                "dead_letters_handled_count{dataset_id=\"dataset_id\",reason=\"reason\"}"
  #              )

  #     assert true ==
  #              String.contains?(
  #                response.body,
  #                "dead_letters_handled_count{dataset_id=\"pirates\",reason=\"%{\\\"alignment\\\" => :invalid_string}\"}"
  #              )

  #     assert [%{app: "Valkyrie", original_message: ^encoded_og_message} | _] = messages
  #   end
  # end

  defp start_telemetry() do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        Alchemist.Dynamic.Supervisor,
        {TelemetryMetricsPrometheus, TelemetryEventHelper.metrics_config(@instance_name)}
      )

    pid
  end

  defp stop_telemetry(pid) do
    case pid do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(Alchemist.Dynamic.Supervisor, pid)
    end
  end
end
