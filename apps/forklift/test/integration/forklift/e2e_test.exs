defmodule Forklift.E2ETest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  import SmartCity.Data, only: [end_of_data: 0]

  import SmartCity.Event,
    only: [
      data_ingest_start: 0,
      dataset_update: 0,
      data_extract_end: 0,
      ingestion_delete: 0,
      ingestion_update: 0
    ]

  import SmartCity.TestHelper

  @instance_name Forklift.instance_name()
  @brokers Application.get_env(:forklift, :elsa_brokers)

  setup do
    # Wait for dependencies to become available
    wait_for_presto_availability()
    wait_for_redis_availability()
    wait_for_kafka_availability()

    Application.put_env(:forklift, :overwrite_mode, true)
    drop_all_tables()
    delete_validated_topics()
    Redix.command!(:redix, ["FLUSHALL"])

    session = create_session()

    [session: session]
  end

  @table_schema [
    %{name: "foo", type: "string"},
    %{name: "bar", type: "integer"}
  ]

  @expected_json_table_values [
    %{"Column" => "foo", "Comment" => "", "Extra" => "", "Type" => "varchar"},
    %{"Column" => "bar", "Comment" => "", "Extra" => "", "Type" => "integer"},
    %{"Column" => "_extraction_start_time", "Comment" => "", "Extra" => "partition key", "Type" => "bigint"},
    %{"Column" => "_ingestion_id", "Comment" => "", "Extra" => "partition key", "Type" => "varchar"}
  ]

  @expected_table_values [
    %{"Column" => "foo", "Comment" => "", "Extra" => "", "Type" => "varchar"},
    %{"Column" => "bar", "Comment" => "", "Extra" => "", "Type" => "integer"},
    %{"Column" => "_extraction_start_time", "Comment" => "", "Extra" => "", "Type" => "bigint"},
    %{"Column" => "_ingestion_id", "Comment" => "", "Extra" => "partition key", "Type" => "varchar"}
  ]

  describe "e2e overwrite mode" do
    test "e2e ingestion begin to ingestion delete", %{session: session} do
      dataset = TDG.create_dataset(%{technical: %{schema: @table_schema}})
      ingestion_1 = TDG.create_ingestion(%{targetDatasets: [dataset.id]})
      ingestion_2 = TDG.create_ingestion(%{targetDatasets: [dataset.id]})

      current_time = Timex.now()
      yyyy_mm_time = current_time |> Timex.format!("%Y_%m", :strftime)

      topic_name = "validated-#{dataset.id}"

      # Extraction 1 (Ingestion 1)
      # ================================================

      extract_time_1 = current_time
      extract_time_unix_1 = current_time |> Timex.to_unix()
      extract_iso_time_1 = extract_time_1 |> Timex.format!("{ISO:Extended:Z}")

      extract_data_1 = %{
        "dataset_ids" => [dataset.id],
        "extract_start_unix" => extract_time_unix_1,
        "ingestion_id" => ingestion_1.id,
        "msgs_extracted" => "2"
      }

      extract_id_1 = get_extract_id(ingestion_1.id, dataset.id, extract_data_1["extract_start_unix"])

      end_of_data_message_1 = %{
        _metadata: %{},
        dataset_ids: [dataset.id],
        extraction_start_time: extract_iso_time_1,
        ingestion_id: ingestion_1.id,
        operational: %{
          timing: []
        },
        payload: end_of_data(),
        version: "0.1"
      }

      message_data_1 = %{
        _metadata: %{},
        dataset_ids: [dataset.id],
        extraction_start_time: extract_iso_time_1,
        ingestion_id: ingestion_1.id,
        operational: %{
          timing: []
        },
        payload: %{
          "foo" => "testFoo",
          "bar" => 12345
        },
        version: "0.1"
      }

      expected_table_data_1 = %{
        "_extraction_start_time" => extract_time_unix_1,
        "_ingestion_id" => ingestion_1.id,
        "bar" => 12345,
        "foo" => "testFoo",
        "os_partition" => "#{yyyy_mm_time}"
      }

      # Extraction 2 (Ingestion 2)
      # ================================================
      extract_time_2 = current_time
      extract_time_unix_2 = extract_time_2 |> Timex.to_unix()
      extract_iso_time_2 = extract_time_2 |> Timex.format!("{ISO:Extended:Z}")

      extract_data_2 = %{
        "dataset_ids" => [dataset.id],
        "extract_start_unix" => extract_time_unix_2,
        "ingestion_id" => ingestion_2.id,
        "msgs_extracted" => "1"
      }

      end_of_data_message_2 = %{
        _metadata: %{},
        dataset_ids: [dataset.id],
        extraction_start_time: extract_iso_time_2,
        ingestion_id: ingestion_2.id,
        operational: %{
          timing: []
        },
        payload: end_of_data(),
        version: "0.1"
      }

      extract_id_2 = get_extract_id(ingestion_2.id, dataset.id, extract_data_2["extract_start_unix"])

      message_data_2 = %{
        _metadata: %{},
        dataset_ids: [dataset.id],
        extraction_start_time: extract_iso_time_2,
        ingestion_id: ingestion_2.id,
        operational: %{
          timing: []
        },
        payload: %{
          "foo" => "testBar",
          "bar" => 54321
        },
        version: "0.1"
      }

      expected_table_data_2 = %{
        "_extraction_start_time" => extract_time_unix_2,
        "_ingestion_id" => ingestion_2.id,
        "bar" => 54321,
        "foo" => "testBar",
        "os_partition" => "#{yyyy_mm_time}"
      }

      # Extraction 3 (Ingestion 1)
      # ================================================
      extract_time_3 = current_time |> Timex.shift(minutes: 1)
      extract_time_unix_3 = extract_time_3 |> Timex.to_unix()
      extract_iso_time_3 = extract_time_3 |> Timex.format!("{ISO:Extended:Z}")

      extract_data_3 = %{
        "dataset_ids" => [dataset.id],
        "extract_start_unix" => extract_time_unix_3,
        "ingestion_id" => ingestion_1.id,
        "msgs_extracted" => "2"
      }

      end_of_data_message_3 = %{
        _metadata: %{},
        dataset_ids: [dataset.id],
        extraction_start_time: extract_iso_time_3,
        ingestion_id: ingestion_1.id,
        operational: %{
          timing: []
        },
        payload: end_of_data(),
        version: "0.1"
      }

      extract_id_3 = get_extract_id(ingestion_1.id, dataset.id, extract_data_3["extract_start_unix"])

      message_data_3 = %{
        _metadata: %{},
        dataset_ids: [dataset.id],
        extraction_start_time: extract_iso_time_3,
        ingestion_id: ingestion_1.id,
        operational: %{
          timing: []
        },
        payload: %{
          "foo" => "testFoo",
          "bar" => 12345
        },
        version: "0.1"
      }

      expected_table_data_3 = %{
        "_extraction_start_time" => extract_time_unix_3,
        "_ingestion_id" => ingestion_1.id,
        "bar" => 12345,
        "foo" => "testFoo",
        "os_partition" => "#{yyyy_mm_time}"
      }

      # Create dataset and ingestions with existing test data
      # ================================================
      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, ingestion_1)
      Brook.Event.send(@instance_name, ingestion_update(), __MODULE__, ingestion_2)

      # Wait for dataset to be stored in state
      # ================================================
      eventually(
        fn ->
          assert Forklift.Datasets.get!(dataset.id) != nil
        end,
        10000
      )

      # Wait for both ingestions to be stored in state
      # ================================================
      eventually(
        fn ->
          assert length(Forklift.Ingestions.get_all!()) == 2
        end,
        10000
      )

      # Wait for tables to exist for the dataset
      # ================================================
      eventually(
        fn ->
          assert @expected_table_values ==
                   "DESCRIBE #{dataset.technical.systemName}"
                   |> execute_query(session)

          assert @expected_json_table_values ==
                   "DESCRIBE #{dataset.technical.systemName}__json"
                   |> execute_query(session)
        end,
        10000
      )

      # Toggle ingestion start, ties dataset to a kafka topic
      # ================================================
      Brook.Event.send(@instance_name, data_ingest_start(), __MODULE__, ingestion_1)

      eventually(
        fn ->
          assert Elsa.topic?(@brokers, topic_name)
        end,
        10000
      )

      # Indicates reaper is done extracting data for extraction 1 and forklift should eventually receive the set amount of messages
      # ================================================
      Brook.Event.send(@instance_name, data_extract_end(), __MODULE__, extract_data_1)

      # Send the kafka messages to topic and verify count key is updated for each messages recieved
      # ================================================
      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(message_data_1)},
        partition: 0
      )

      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(message_data_1)},
        partition: 0
      )

      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(end_of_data_message_1)},
        partition: 0
      )

      # # Indicates reaper is done extracting data for extraction 2 and forklift should eventually receive the set amount of messages
      # ================================================
      Brook.Event.send(@instance_name, data_extract_end(), __MODULE__, extract_data_2)

      # Send the kafka messages to topic and verify count key is updated for each messages recieved
      # ================================================
      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(message_data_2)},
        partition: 0
      )

      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(end_of_data_message_2)},
        partition: 0
      )

      # Verify dataset table contents have been updated with data from the received messages
      # All Ingestion 1 data should be present from the 1st extraction
      # All Ingestion 2 data should be present 2nd extraction
      # ================================================
      eventually(
        fn ->
          try do
            query = "select * from #{dataset.technical.systemName}"

            result =
              session
              |> Prestige.query!(query)
              |> Prestige.Result.as_maps()

            assert Enum.sort(result) ==
                     Enum.sort([
                       expected_table_data_1,
                       expected_table_data_1,
                       expected_table_data_2
                     ])
          rescue
            error -> assert error == nil
          end
        end,
        30000
      )

      # Trigger delete of all ingestion 2 data and verify ingestion is reduced accordingly
      # ================================================
      Brook.Event.send(@instance_name, ingestion_delete(), __MODULE__, ingestion_2)

      eventually(
        fn ->
          assert length(Forklift.Ingestions.get_all!()) == 1
        end,
        10000
      )

      # # Indicates reaper is done extracting data for extraction 3 and forklift should eventually receive the set amount of messages
      # ================================================
      Brook.Event.send(@instance_name, data_extract_end(), __MODULE__, extract_data_3)

      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(message_data_3)},
        partition: 0
      )

      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(message_data_3)},
        partition: 0
      )

      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(end_of_data_message_3)},
        partition: 0
      )

      # Verify dataset table contents have been updated with data from the received messages
      # All Ingestion 1 data should overwritten with data from the 3rd extraction
      # All Ingestion 2 data should be deleted
      # ================================================
      eventually(
        fn ->
          try do
            query = "select * from #{dataset.technical.systemName}"

            result =
              session
              |> Prestige.query!(query)
              |> Prestige.Result.as_maps()

            assert Enum.sort(result) ==
                     Enum.sort([
                       expected_table_data_3,
                       expected_table_data_3
                     ])
          rescue
            error -> assert error == nil
          end
        end,
        10000
      )
    end
  end

  defp execute_query(query, session) do
    session
    |> Prestige.execute!(query)
    |> Prestige.Result.as_maps()
  end

  def create_session() do
    Application.get_env(:prestige, :session_opts)
    |> Prestige.new_session()
  end

  def wait_for_presto_availability(max_attempts \\ 20, delay_ms \\ 5000) do
    IO.puts("Waiting for Presto container to become available...")

    Enum.reduce_while(1..max_attempts, :unavailable, fn attempt, _acc ->
      case check_presto_connection() do
        :available ->
          IO.puts("Presto is available after #{attempt} attempts")
          {:halt, :available}

        :unavailable ->
          if attempt == max_attempts do
            raise "Presto container did not become available after #{max_attempts} attempts (#{max_attempts * delay_ms / 1000} seconds)"
          else
            IO.puts("Presto not ready, attempt #{attempt}/#{max_attempts}, retrying in #{delay_ms}ms...")
            Process.sleep(delay_ms)
            {:cont, :unavailable}
          end
      end
    end)
  end

  def check_presto_connection() do
    # Use Prestige directly to bypass any mocks for integration tests
    try do
      session = Application.get_env(:prestige, :session_opts) |> Prestige.new_session()

      case Prestige.execute(session, "SELECT 1") do
        {:ok, _} -> :available
        {:error, %Prestige.ConnectionError{}} -> :unavailable
        {:error, _} -> :unavailable
      end
    rescue
      _ -> :unavailable
    end
  end

  def wait_for_redis_availability(max_attempts \\ 30, delay_ms \\ 1000) do
    IO.puts("Waiting for Redis container to become available...")

    Enum.reduce_while(1..max_attempts, :unavailable, fn attempt, _acc ->
      case check_redis_connection() do
        :available ->
          IO.puts("Redis is available after #{attempt} attempts")
          {:halt, :available}

        :unavailable ->
          if attempt == max_attempts do
            raise "Redis container did not become available after #{max_attempts} attempts (#{max_attempts * delay_ms / 1000} seconds)"
          else
            IO.puts("Redis not ready, attempt #{attempt}/#{max_attempts}, retrying in #{delay_ms}ms...")
            Process.sleep(delay_ms)
            {:cont, :unavailable}
          end
      end
    end)
  end

  def check_redis_connection() do
    try do
      case Redix.command(:redix, ["PING"]) do
        {:ok, "PONG"} -> :available
        _ -> :unavailable
      end
    rescue
      _ -> :unavailable
    end
  end

  def wait_for_kafka_availability(max_attempts \\ 30, delay_ms \\ 1000) do
    IO.puts("Waiting for Kafka brokers to become available...")

    Enum.reduce_while(1..max_attempts, :unavailable, fn attempt, _acc ->
      case check_kafka_connection() do
        :available ->
          IO.puts("Kafka is available after #{attempt} attempts")
          {:halt, :available}

        :unavailable ->
          if attempt == max_attempts do
            raise "Kafka brokers did not become available after #{max_attempts} attempts (#{max_attempts * delay_ms / 1000} seconds)"
          else
            IO.puts("Kafka not ready, attempt #{attempt}/#{max_attempts}, retrying in #{delay_ms}ms...")
            Process.sleep(delay_ms)
            {:cont, :unavailable}
          end
      end
    end)
  end

  def check_kafka_connection() do
    try do
      case Elsa.list_topics(@brokers) do
        {:ok, _topics} -> :available
        _ -> :unavailable
      end
    rescue
      _ -> :unavailable
    end
  end

  def drop_all_tables() do
    case PrestigeHelper.execute_query("show tables") do
      {:ok, result} ->
        result |> Prestige.Result.as_maps() |> Enum.each(&PrestigeHelper.drop_table/1)

      {:error, %Prestige.ConnectionError{}} ->
        # Presto is not available, skip table cleanup
        # This is acceptable for tests that may run without Presto
        :ok

      {:error, reason} ->
        # Log other errors but don't crash the test setup
        IO.puts("Warning: Failed to drop tables: #{inspect(reason)}")
        :ok
    end
  end

  def delete_validated_topics() do
    {:ok, topics} = Elsa.list_topics(@brokers)

    topics
    |> Enum.filter(fn {topic, _partition} -> topic =~ "validated" end)
    |> Enum.each(fn {topic, _partition} -> Elsa.delete_topic(@brokers, topic) end)
  end

  defp get_count_key(extract_id) do
    extract_id <> "_count"
  end

  defp get_target_key(extract_id) do
    extract_id <> "_target"
  end

  defp get_extract_id(ingestion_id, dataset_id, extract_time) do
    ingestion_id <> "_" <> dataset_id <> "_" <> Integer.to_string(extract_time)
  end
end
