defmodule ValkyrieTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :valkyrie

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  import SmartCity.Event,
    only: [data_ingest_start: 0, dataset_update: 0, data_standardization_end: 0]

  alias TelemetryEvent.Helper.TelemetryEventHelper

  @instance_name Valkyrie.instance_name()
  @dlq_topic Application.get_env(:dead_letter, :driver) |> get_in([:init_args, :topic])

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

    pid = start_telemetry()

    on_exit(fn ->
      stop_telemetry(pid)
    end)

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

    input_topic = "#{input_topic_prefix()}-#{dataset.id}"
    output_topic = "#{output_topic_prefix()}-#{dataset.id}"

    Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, dataset)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)

    TestHelpers.produce_messages(messages, input_topic, elsa_brokers())

    {:ok, %{output_topic: output_topic, messages: messages, invalid_message: invalid_message, dataset: dataset}}
  end

  test "valkyrie updates the operational struct", %{output_topic: output_topic} do
    eventually fn ->
      messages = TestHelpers.get_data_messages_from_kafka_with_timing(output_topic, elsa_brokers())

      assert [%{operational: %{timing: [%{app: "valkyrie"} | _]}} | _] = messages
    end
  end

  test "valkyrie only starts the processes for ingest once on event handle", %{messages: messages} do
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

    messages = Enum.map(messages, fn message -> Map.put(message, :dataset_id, dataset.id) end)

    input_topic = "#{input_topic_prefix()}-#{dataset.id}"
    output_topic = "#{output_topic_prefix()}-#{dataset.id}"

    Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, dataset)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)

    1..100
    |> Enum.each(fn _ ->
      Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, dataset)
    end)

    TestHelpers.produce_messages(messages, input_topic, elsa_brokers())

    eventually fn ->
      messages = TestHelpers.get_data_messages_from_kafka_with_timing(output_topic, elsa_brokers())

      assert [%{operational: %{timing: [%{app: "valkyrie"} | _]}} | _] = messages
    end
  end

  test "valkyrie updates the view state of running ingestions on dataset update" do
    dataset =
      TDG.create_dataset(%{
        id: "pirates3",
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string"},
            %{name: "alignment", type: "string"},
            %{name: "age", type: "string"}
          ]
        }
      })

    input_topic = "#{input_topic_prefix()}-#{dataset.id}"
    output_topic = "#{output_topic_prefix()}-#{dataset.id}"

    Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, dataset)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)

    updated_schema = [
      %{name: "name", type: "string"},
      %{name: "alignment", type: "string"},
      %{name: "age", type: "integer"}
    ]

    dataset = put_in(dataset, [:technical, :schema], updated_schema)
    Brook.Event.send(@instance_name, dataset_update(), :valkyrie, dataset)

    invalid_message =
      TestHelpers.create_data(%{
        payload: %{"name" => "Jack Sparrow", "alignment" => "chaotic", "age" => "thirty-two"},
        dataset_id: dataset.id
      })

    messages = [
      invalid_message,
      TestHelpers.create_data(%{
        payload: %{"name" => "Will Turner", "alignment" => "good", "age" => 25},
        dataset_id: dataset.id
      })
    ]

    eventually fn ->
      actual_schema = Brook.get!(Valkyrie.instance_name(), :datasets, dataset.id) |> get_in([:technical, :schema])
      assert actual_schema == updated_schema
    end

    TestHelpers.produce_messages(messages, input_topic, elsa_brokers())

    eventually(
      fn ->
        output_messages = TestHelpers.get_data_messages_from_kafka(output_topic, elsa_brokers())

        assert messages -- [invalid_message] == output_messages
      end,
      500,
      20
    )
  end

  test "valkyrie does not start a stopped processor on dataset update" do
    dataset =
      TDG.create_dataset(%{
        id: "pirates4",
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string"},
            %{name: "alignment", type: "string"},
            %{name: "age", type: "string"}
          ]
        }
      })

    input_topic = "#{input_topic_prefix()}-#{dataset.id}"

    Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, dataset)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)

    eventually fn ->
      assert Valkyrie.DatasetSupervisor.is_started?(dataset.id) == true
    end

    Brook.Event.send(@instance_name, data_standardization_end(), :valkyrie, %{"dataset_id" => dataset.id})

    eventually fn ->
      assert Valkyrie.DatasetSupervisor.is_started?(dataset.id) == false
    end

    Brook.Event.send(@instance_name, dataset_update(), :valkyrie, dataset)

    eventually fn ->
      assert Valkyrie.DatasetSupervisor.is_started?(dataset.id) == false
    end
  end

  test "valkyrie rejects unparseable messages and passes the rest through", %{
    output_topic: output_topic,
    messages: messages,
    invalid_message: invalid_message
  } do
    eventually fn ->
      output_messages = TestHelpers.get_data_messages_from_kafka(output_topic, elsa_brokers())

      assert messages -- [invalid_message] == output_messages
    end
  end

  test "valkyrie sends invalid data messages to the dlq", %{invalid_message: invalid_message} do
    encoded_og_message = invalid_message |> Jason.encode!()

    metrics_port = Application.get_env(:telemetry_event, :metrics_port)

    eventually fn ->
      messages = TestHelpers.get_dlq_messages_from_kafka(@dlq_topic, elsa_brokers())

      assert :ok =
               [
                 dataset_id: "dataset_id",
                 reason: "reason"
               ]
               |> TelemetryEvent.add_event_metrics([:dead_letters_handled])

      response = HTTPoison.get!("http://localhost:#{metrics_port}/metrics")

      assert true ==
               String.contains?(
                 response.body,
                 "dead_letters_handled_count{dataset_id=\"dataset_id\",reason=\"reason\"}"
               )

      assert true ==
               String.contains?(
                 response.body,
                 "dead_letters_handled_count{dataset_id=\"pirates\",reason=\"%{\\\"alignment\\\" => :invalid_string}\"}"
               )

      assert [%{app: "Valkyrie", original_message: ^encoded_og_message} | _] = messages
    end
  end

  defp start_telemetry() do
    {:ok, pid} =
      DynamicSupervisor.start_child(
        Valkyrie.Dynamic.Supervisor,
        {TelemetryMetricsPrometheus, TelemetryEventHelper.metrics_config(@instance_name)}
      )

    pid
  end

  defp stop_telemetry(pid) do
    case pid do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(Valkyrie.Dynamic.Supervisor, pid)
    end
  end
end
