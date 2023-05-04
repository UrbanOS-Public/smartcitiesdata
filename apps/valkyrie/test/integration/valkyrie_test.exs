defmodule ValkyrieTest do
  use ExUnit.Case
  use Divo
  use Properties, otp_app: :valkyrie

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  import SmartCity.Event,
    only: [data_ingest_start: 0, dataset_update: 0, data_standardization_end: 0, dataset_delete: 0]

  alias TelemetryEvent.Helper.TelemetryEventHelper

  @instance_name Valkyrie.instance_name()
  @dlq_topic Application.get_env(:dead_letter, :driver) |> get_in([:init_args, :topic])

  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic_prefix, generic: true)

  setup do
    dataset_id = Faker.UUID.v4()
    dataset_id2 = Faker.UUID.v4()

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string", ingestion_field_selector: "name"},
            %{name: "alignment", type: "string", ingestion_field_selector: "alignment"},
            %{name: "age", type: "string", ingestion_field_selector: "age"}
          ]
        }
      })

    dataset2 =
      TDG.create_dataset(%{
        id: dataset_id2,
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string", ingestion_field_selector: "name"},
            %{name: "alignment", type: "string", ingestion_field_selector: "alignment"},
            %{name: "age", type: "string", ingestion_field_selector: "age"}
          ]
        }
      })

    ingestion = TDG.create_ingestion(%{targetDatasets: [dataset_id, dataset_id2]})

    invalid_message =
      TestHelpers.create_data(%{
        payload: %{"name" => "Blackbeard", "alignment" => %{"invalid" => "string"}, "age" => "thirty-two"},
        dataset_ids: [dataset_id, dataset_id2]
      })

    messages = [
      TestHelpers.create_data(%{
        payload: %{"name" => "Jack Sparrow", "alignment" => "chaotic", "age" => "32"},
        dataset_ids: [dataset_id, dataset_id2]
      }),
      invalid_message,
      TestHelpers.create_data(%{
        payload: %{"name" => "Will Turner", "alignment" => "good", "age" => "25"},
        dataset_ids: [dataset_id, dataset_id2]
      }),
      TestHelpers.create_data(%{
        payload: %{"name" => "Barbosa", "alignment" => "evil", "age" => "100"},
        dataset_ids: [dataset_id, dataset_id2]
      })
    ]

    input_topic = "#{input_topic_prefix()}-#{dataset_id}"
    input_topic2 = "#{input_topic_prefix()}-#{dataset_id2}"
    output_topic = "#{output_topic_prefix()}-#{dataset_id}"
    output_topic2 = "#{output_topic_prefix()}-#{dataset_id2}"

    Brook.Event.send(@instance_name, dataset_update(), :valkyrie, dataset)
    Brook.Event.send(@instance_name, dataset_update(), :valkyrie, dataset2)

    eventually fn ->
      assert Brook.get!(@instance_name, :datasets, dataset_id) != nil
      assert Brook.get!(@instance_name, :datasets, dataset_id2) != nil
    end

    Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, ingestion)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic2)

    TestHelpers.produce_messages(messages, input_topic, elsa_brokers())
    TestHelpers.produce_messages(messages, input_topic2, elsa_brokers())

    on_exit(fn ->
      delete_all_datasets()

      terminate_all_supervisors()

      eventually fn ->
        assert any_supervisors_exist?() == false
      end
    end)

    {:ok,
     %{
       output_topics: [output_topic, output_topic2],
       messages: messages,
       invalid_message: invalid_message,
       dataset: dataset,
       dataset2: dataset2
     }}
  end

  setup_all do
    pid = start_telemetry()

    on_exit(fn ->
      stop_telemetry(pid)
    end)
  end

  test "valkyrie updates the operational struct", %{output_topics: [output_topic, output_topic2]} do
    eventually fn ->
      first_topic_messages = TestHelpers.get_data_messages_from_kafka_with_timing(output_topic, elsa_brokers())
      second_topic_messages = TestHelpers.get_data_messages_from_kafka_with_timing(output_topic2, elsa_brokers())

      assert [%{operational: %{timing: [%{app: "valkyrie"} | _]}} | _] = first_topic_messages
      assert [%{operational: %{timing: [%{app: "valkyrie"} | _]}} | _] = second_topic_messages
    end
  end

  test "valkyrie only starts the processes for ingest once on event handle", %{messages: messages} do
    dataset_id = Faker.UUID.v4()
    dataset_id2 = Faker.UUID.v4()

    dataset =
      TDG.create_dataset(%{
        id: dataset_id,
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string", ingestion_field_selector: "name"},
            %{name: "alignment", type: "string", ingestion_field_selector: "alignment"},
            %{name: "age", type: "string", ingestion_field_selector: "age"}
          ]
        }
      })

    dataset2 =
      TDG.create_dataset(%{
        id: dataset_id2,
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string", ingestion_field_selector: "name"},
            %{name: "alignment", type: "string", ingestion_field_selector: "alignment"},
            %{name: "age", type: "string", ingestion_field_selector: "age"}
          ]
        }
      })

    ingestion = TDG.create_ingestion(%{targetDatasets: [dataset_id, dataset_id2]})

    messages = Enum.map(messages, fn message -> Map.put(message, :dataset_ids, [dataset_id, dataset_id2]) end)

    input_topic = "#{input_topic_prefix()}-#{dataset_id}"
    input_topic2 = "#{input_topic_prefix()}-#{dataset_id2}"
    output_topic = "#{output_topic_prefix()}-#{dataset_id}"
    output_topic2 = "#{output_topic_prefix()}-#{dataset_id2}"

    Brook.Event.send(@instance_name, dataset_update(), :valkyrie, dataset)
    Brook.Event.send(@instance_name, dataset_update(), :valkyrie, dataset2)

    Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, ingestion)

    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic2)

    1..10
    |> Enum.each(fn _ ->
      Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, ingestion)
    end)

    TestHelpers.produce_messages(messages, input_topic, elsa_brokers())
    TestHelpers.produce_messages(messages, input_topic2, elsa_brokers())

    eventually fn ->
      first_topic_messages = TestHelpers.get_data_messages_from_kafka_with_timing(output_topic, elsa_brokers())
      second_topic_messages = TestHelpers.get_data_messages_from_kafka_with_timing(output_topic2, elsa_brokers())

      assert [%{operational: %{timing: [%{app: "valkyrie"} | _]}} | _] = first_topic_messages
      assert [%{operational: %{timing: [%{app: "valkyrie"} | _]}} | _] = second_topic_messages
    end
  end

  test "valkyrie updates the view state of running ingestions on dataset update" do
    dataset =
      TDG.create_dataset(%{
        id: Faker.UUID.v4(),
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string", ingestion_field_selector: "name"},
            %{name: "alignment", type: "string", ingestion_field_selector: "alignment"},
            %{name: "age", type: "string", ingestion_field_selector: "age"}
          ]
        }
      })

    ingestion = TDG.create_ingestion(%{targetDatasets: [dataset.id]})

    input_topic = "#{input_topic_prefix()}-#{dataset.id}"
    output_topic = "#{output_topic_prefix()}-#{dataset.id}"
    Brook.Event.send(@instance_name, dataset_update(), :valkyrie, dataset)

    eventually fn ->
      dataset = Brook.get!(@instance_name, :datasets, dataset.id)
      assert dataset != nil
    end

    Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, ingestion)
    TestHelpers.wait_for_topic(elsa_brokers(), input_topic)

    updated_schema = [
      %{name: "name", type: "string", ingestion_field_selector: "name"},
      %{name: "alignment", type: "string", ingestion_field_selector: "alignment"},
      %{name: "age", type: "integer", ingestion_field_selector: "age"}
    ]

    dataset = put_in(dataset, [:technical, :schema], updated_schema)
    Brook.Event.send(@instance_name, dataset_update(), :valkyrie, dataset)

    invalid_message =
      TestHelpers.create_data(%{
        payload: %{
          "name" => "Jack Sparrow",
          "alignment" => "chaotic",
          "age" => "thirty-two"
        },
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
      actual_schema = Brook.get!(@instance_name, :datasets, dataset.id) |> get_in([:technical, :schema])
      assert actual_schema == updated_schema
    end

    TestHelpers.produce_messages(messages, input_topic, elsa_brokers())

    eventually fn ->
      output_messages = TestHelpers.get_data_messages_from_kafka(output_topic, elsa_brokers())
      assert messages -- [invalid_message] == output_messages
    end
  end

  test "valkyrie does not start a stopped processor on dataset update" do
    dataset =
      TDG.create_dataset(%{
        id: Faker.UUID.v4(),
        technical: %{
          sourceType: "ingest",
          schema: [
            %{name: "name", type: "string"},
            %{name: "alignment", type: "string"},
            %{name: "age", type: "string"}
          ]
        }
      })

    ingestion = TDG.create_ingestion(%{targetDatasets: [dataset.id]})

    input_topic = "#{input_topic_prefix()}-#{dataset.id}"

    Brook.Event.send(@instance_name, dataset_update(), :valkyrie, dataset)

    eventually fn ->
      assert Brook.get!(@instance_name, :datasets, dataset.id) != nil
    end

    Brook.Event.send(@instance_name, data_ingest_start(), :valkyrie, ingestion)
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
    output_topics: [output_topic, output_topic2],
    messages: messages,
    invalid_message: invalid_message
  } do
    eventually fn ->
      first_topic_output_messages = TestHelpers.get_data_messages_from_kafka(output_topic, elsa_brokers())
      second_topic_output_messages = TestHelpers.get_data_messages_from_kafka(output_topic2, elsa_brokers())

      assert messages -- [invalid_message] == first_topic_output_messages
      assert messages -- [invalid_message] == second_topic_output_messages
    end
  end

  test "valkyrie sends invalid data messages to the dlq", %{invalid_message: invalid_message, dataset: dataset} do
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

      expected =
        "dead_letters_handled_count{dataset_id=\"#{dataset.id}\",reason=\"\\\"%{\\\\\\\\\"alignment\\\\\\\\\" => :invalid_string}\\\"\"}"

      assert true ==
               String.contains?(
                 response.body,
                 expected
               )

      assert Enum.any?(messages, fn %{original_message: message} -> message == encoded_og_message end)
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

  defp terminate_all_supervisors() do
    children = DynamicSupervisor.which_children(Valkyrie.Dynamic.Supervisor)

    Enum.each(children, fn
      {:undefined, pid, :supervisor, [Valkyrie.DatasetSupervisor]} ->
        DynamicSupervisor.terminate_child(Valkyrie.Dynamic.Supervisor, pid)

      _ ->
        nil
    end)
  end

  defp any_supervisors_exist?() do
    children = DynamicSupervisor.which_children(Valkyrie.Dynamic.Supervisor)

    Enum.any?(children, fn
      {:undefined, _pid, :supervisor, [Valkyrie.DatasetSupervisor]} -> true
      _ -> false
    end)
  end

  defp delete_all_datasets() do
    eventually fn ->
                 {:ok, datasets} = Brook.get_all(@instance_name, :datasets)

                 Enum.each(datasets, fn {_dataset_id, dataset} ->
                   Brook.Event.send(@instance_name, dataset_delete(), :valkyrie, dataset)
                 end)

                 assert Brook.get_all(@instance_name, :datasets) == {:ok, %{}}
               end,
               10_000
  end
end
