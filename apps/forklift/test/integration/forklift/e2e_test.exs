defmodule Forklift.E2ETest do
  use ExUnit.Case

  alias SmartCity.TestDataGenerator, as: TDG
  alias Pipeline.Writer.TableWriter.Helper.PrestigeHelper

  import SmartCity.Event,
    only: [
      data_ingest_start: 0,
      dataset_update: 0,
      data_extract_end: 0
    ]

  import SmartCity.TestHelper

  @instance_name Forklift.instance_name()
  @brokers Application.get_env(:forklift, :elsa_brokers)

  setup do
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

  describe "e2e" do
    test "e2e", %{session: session} do
      dataset = TDG.create_dataset(%{technical: %{schema: @table_schema}})
      ingestion = TDG.create_ingestion(%{targetDatasets: [dataset.id]})

      current_time = Timex.now()
      iso_time = current_time |> Timex.format!("{ISO:Extended:Z}")
      yyyy_mm_time = current_time |> Timex.format!("%Y_%m", :strftime)

      extract_data = %{
        "dataset_ids" => [dataset.id],
        "extract_start_unix" => current_time |> Timex.to_unix(),
        "ingestion_id" => ingestion.id,
        "msgs_extracted" => "3"
      }

      topic_name = "validated-#{dataset.id}"
      extract_id = get_extract_id(ingestion.id, dataset.id, extract_data["extract_start_unix"])

      message_data = %{
        _metadata: %{},
        dataset_ids: [dataset.id],
        extraction_start_time: iso_time,
        ingestion_id: ingestion.id,
        operational: %{
          timing: []
        },
        payload: %{
          "foo" => "testFoo",
          "bar" => 12345
        },
        version: "0.1"
      }

      expected_table_data = %{
        "_extraction_start_time" => current_time |> Timex.to_unix(),
        "_ingestion_id" => ingestion.id,
        "bar" => 12345,
        "foo" => "testFoo",
        "os_partition" => "#{yyyy_mm_time}"
      }

      Brook.Event.send(@instance_name, dataset_update(), __MODULE__, dataset)

      eventually(
        fn ->
          assert Forklift.Datasets.get!(dataset.id) != nil
        end,
        10000
      )

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

      Brook.Event.send(@instance_name, data_ingest_start(), __MODULE__, ingestion)

      eventually(
        fn ->
          assert Elsa.topic?(@brokers, topic_name)
        end,
        10000
      )

      Brook.Event.send(@instance_name, data_extract_end(), __MODULE__, extract_data)

      eventually(fn ->
        assert Redix.command!(:redix, ["GET", get_target_key(extract_id)]) == "3"
      end)

      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(message_data)},
        partition: 0
      )

      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(message_data)},
        partition: 0
      )

      eventually(fn ->
        assert Redix.command!(:redix, ["GET", get_count_key(extract_id)]) == "2"
      end)

      Elsa.Producer.produce(
        @brokers,
        topic_name,
        {"test", Jason.encode!(message_data)},
        partition: 0
      )

      eventually(
        fn ->
          assert Redix.command!(:redix, ["GET", get_count_key(extract_id)]) == nil
        end,
        10000
      )

      eventually(
        fn ->
          try do
            query2 = "show tables"
            session |> Prestige.query!(query2) |> IO.inspect(label: "a;lksdjfasl;dkfij")
            query = "select * from #{dataset.technical.systemName}" |> IO.inspect(label: "query")

            result =
              session
              |> Prestige.query!(query)
              |> Prestige.Result.as_maps()

            assert result == [
                     expected_table_data,
                     expected_table_data,
                     expected_table_data
                   ]
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

  def drop_all_tables() do
    {:ok, result} = PrestigeHelper.execute_query("show tables")
    result |> Prestige.Result.as_maps() |> Enum.each(&PrestigeHelper.drop_table/1)
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
