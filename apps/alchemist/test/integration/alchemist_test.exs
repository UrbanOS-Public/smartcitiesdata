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

    dataset2 =
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

    ingestion = TDG.create_ingestion(%{targetDatasets: [dataset.id, dataset2.id]})

    pid = start_telemetry()

    on_exit(fn ->
      stop_telemetry(pid)
    end)

    pre_transform_messages_for_first_dataset = [
      TestHelpers.create_data(%{
        payload: %{"name" => "Jack Sparrow", "alignment" => "chaotic", "age" => "32"},
        dataset_id: "none"
      }),
      TestHelpers.create_data(%{
        payload: %{"name" => "Will Turner", "alignment" => "good", "age" => "25"},
        dataset_id: "none"
      }),
      TestHelpers.create_data(%{
        payload: %{"name" => "Barbosa", "alignment" => "evil", "age" => "100"},
        dataset_id: "none"
      })
    ]

    # pre_transform_messages_for_second_dataset = [
    #   TestHelpers.create_data(%{
    #     payload: %{"name" => "Jack Sparrow", "alignment" => "chaotic", "age" => "32"},
    #     dataset_id: dataset2.id
    #   }),
    #   TestHelpers.create_data(%{
    #     payload: %{"name" => "Will Turner", "alignment" => "good", "age" => "25"},
    #     dataset_id: dataset2.id
    #   }),
    #   TestHelpers.create_data(%{
    #     payload: %{"name" => "Barbosa", "alignment" => "evil", "age" => "100"},
    #     dataset_id: dataset2.id
    #   })
    # ]

    input_topic = "#{input_topic_prefix()}-#{ingestion.id}"

    output_topics = [
      "#{output_topic_prefix()}-#{dataset.id}",
      "#{output_topic_prefix()}-#{dataset2.id}"
    ]

    Brook.Event.send(@instance_name, ingestion_update(), :alchemist, ingestion)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)

    TestHelpers.produce_messages(pre_transform_messages_for_first_dataset, input_topic, elsa_brokers())
    # TestHelpers.produce_messages(pre_transform_messages_for_second_dataset, input_topic, elsa_brokers())

    {:ok,
     %{
       output_topics: output_topics,
       pre_transform_messages_for_first_dataset: pre_transform_messages_for_first_dataset,
       # pre_transform_messages_for_second_dataset: pre_transform_messages_for_second_dataset,
       datasets: [dataset, dataset2]
     }}
  end

  test "alchemist updates the operational struct", %{
    output_topics: [dataset1_topic, dataset2_topic],
    pre_transform_messages_for_first_dataset: pre_transform_messages_for_first_dataset
    # pre_transform_messages_for_second_dataset: pre_transform_messages_for_second_dataset,
  } do
    eventually fn ->
      post_transform_messages_for_first_topic =
        TestHelpers.get_data_messages_from_kafka_with_timing(dataset1_topic, elsa_brokers())

      post_transform_messages_for_second_topic =
        TestHelpers.get_data_messages_from_kafka_with_timing(dataset2_topic, elsa_brokers())

      assert pre_transform_messages_for_first_dataset == post_transform_messages_for_first_topic
      assert pre_transform_messages_for_first_dataset == post_transform_messages_for_second_topic
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
