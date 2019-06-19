defmodule Reaper.FullTest do
  use ExUnit.Case
  use Divo
  use Tesla
  use Placebo
  require Logger
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.TestHelper

  @endpoints Application.get_env(:reaper, :elsa_brokers)
  @output_topic_prefix Application.get_env(:reaper, :output_topic_prefix)

  @pre_existing_dataset_id "00000-0000"
  @partial_load_dataset_id "11111-1112"

  @json_file_name "vehicle_locations.json"
  @gtfs_file_name "gtfs-realtime.pb"
  @csv_file_name "random_stuff.csv"

  setup_all do
    Temp.track!()
    Application.put_env(:reaper, :download_dir, Temp.mkdir!())

    # NOTE: using Bypass in setup all b/c we have no expectations.
    # If we add any, we'll need to move this, per https://github.com/pspdfkit-labs/bypass#example
    bypass = Bypass.open()

    bypass
    |> TestUtils.bypass_file(@gtfs_file_name)
    |> TestUtils.bypass_file(@json_file_name)
    |> TestUtils.bypass_file(@csv_file_name)

    eventually(fn ->
      {type, result} = get("http://localhost:#{bypass.port}/#{@csv_file_name}")
      type == :ok and result.status == 200
    end)

    {:ok, bypass: bypass}
  end

  describe "pre-existing dataset" do
    setup %{bypass: bypass} do
      Redix.command(:redix, ["FLUSHALL"])

      pre_existing_dataset =
        TDG.create_dataset(%{
          id: @pre_existing_dataset_id,
          technical: %{
            cadence: 1_000,
            sourceUrl: "http://localhost:#{bypass.port}/#{@json_file_name}",
            sourceFormat: "json"
          }
        })

      Elsa.create_topic(@endpoints, "#{@output_topic_prefix}-#{@pre_existing_dataset_id}")

      Dataset.write(pre_existing_dataset)
      :ok
    end

    test "configures and ingests a json-source that was added before reaper started" do
      expected =
        TestUtils.create_data(%{
          dataset_id: @pre_existing_dataset_id,
          payload: %{
            latitude: 39.9613,
            vehicle_id: 41_015,
            update_time: "2019-02-14T18:53:23.498889+00:00",
            longitude: -83.0074
          }
        })

      topic = "#{@output_topic_prefix}-#{@pre_existing_dataset_id}"

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, @endpoints)
        last_one = List.last(results)

        assert expected == last_one
      end)
    end
  end

  describe "partial-existing dataset" do
    setup %{bypass: bypass} do
      Redix.command(:redix, ["FLUSHALL"])
      {:ok, pid} = Agent.start_link(fn -> %{has_raised: false} end)

      allow Reaper.Loader.load(any(), any(), any()),
        meck_options: [:passthrough],
        exec: fn value, config, timestamp ->
          case {value, Agent.get(pid, fn s -> s.has_raised end)} do
            {%{"my_string" => "Erin"}, false} ->
              Agent.update(pid, fn s -> %{s | has_raised: true} end)
              raise "Bring this thing down!"

            _ ->
              :meck.passthrough([value, config, timestamp])
          end
        end

      pre_existing_dataset =
        TDG.create_dataset(%{
          id: @partial_load_dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
            sourceFormat: "csv",
            sourceType: "batch"
          }
        })

      Dataset.write(pre_existing_dataset)
      Elsa.create_topic(@endpoints, "#{@output_topic_prefix}-#{@partial_load_dataset_id}")
      :ok
    end

    test "configures and ingests a csv datasource that was partially loaded before reaper restarted", %{bypass: _bypass} do
      expected = [
        TestUtils.create_data(%{
          dataset_id: @partial_load_dataset_id,
          payload: %{my_date: "Spot", my_int: "1", my_string: "Austin"}
        }),
        TestUtils.create_data(%{
          dataset_id: @partial_load_dataset_id,
          payload: %{my_date: "Bella", my_int: "2", my_string: "Erin"}
        }),
        TestUtils.create_data(%{
          dataset_id: @partial_load_dataset_id,
          payload: %{my_date: "Max", my_int: "3", my_string: "Ben"}
        })
      ]

      topic = "#{@output_topic_prefix}-#{@partial_load_dataset_id}"

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, @endpoints)

        assert expected == results
      end)
    end
  end

  describe "No pre-existing datasets" do
    setup do
      Redix.command(:redix, ["FLUSHALL"])
      :ok
    end

    test "configures and ingests a gtfs source", %{bypass: bypass} do
      dataset_id = "12345-6789"
      topic = "#{@output_topic_prefix}-#{dataset_id}"

      gtfs_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: 1_000,
            sourceUrl: "http://localhost:#{bypass.port}/#{@gtfs_file_name}",
            sourceFormat: "gtfs"
          }
        })

      Dataset.write(gtfs_dataset)
      Elsa.create_topic(@endpoints, topic)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, @endpoints)

        assert [%{payload: %{id: "1004"}} | _] = results
      end)
    end

    test "configures and ingests a json source", %{bypass: bypass} do
      dataset_id = "23456-7891"
      topic = "#{@output_topic_prefix}-#{dataset_id}"

      json_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: 1_000,
            sourceUrl: "http://localhost:#{bypass.port}/#{@json_file_name}",
            sourceFormat: "json"
          }
        })

      Dataset.write(json_dataset)
      Elsa.create_topic(@endpoints, topic)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, @endpoints)

        assert [%{payload: %{vehicle_id: 51_127}} | _] = results
      end)
    end

    test "configures and ingests a csv source", %{bypass: bypass} do
      dataset_id = "34567-8912"
      topic = "#{@output_topic_prefix}-#{dataset_id}"

      csv_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
            sourceFormat: "csv",
            sourceType: "batch",
            schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
          }
        })

      Dataset.write(csv_dataset)
      Elsa.create_topic(@endpoints, topic)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, @endpoints)

        assert [%{payload: %{name: "Austin"}} | _] = results
        assert false == File.exists?(dataset_id)
      end)
    end

    test "saves last_success_time to redis", %{bypass: bypass} do
      dataset_id = "12345-5555"

      gtfs_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: 1_000,
            sourceUrl: "http://localhost:#{bypass.port}/#{@gtfs_file_name}",
            sourceFormat: "gtfs"
          }
        })

      Dataset.write(gtfs_dataset)
      Elsa.create_topic(@endpoints, "#{@output_topic_prefix}-#{dataset_id}")

      eventually(fn ->
        {:ok, result} = Redix.command(:redix, ["GET", "reaper:derived:#{dataset_id}"])
        assert result != nil

        timestamp =
          result
          |> Jason.decode!()
          |> Map.get("timestamp")
          |> DateTime.from_iso8601()

        assert {:ok, date_time_from_redis, 0} = timestamp
      end)
    end
  end

  describe "One time Batch" do
    setup do
      Redix.command(:redix, ["FLUSHALL"])
      :ok
    end

    test "cadence of once is only processed once", %{bypass: bypass} do
      dataset_id = "only-once"
      topic = "#{@output_topic_prefix}-#{dataset_id}"

      csv_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: "once",
            sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
            sourceFormat: "csv",
            sourceType: "batch",
            schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
          }
        })

      Dataset.write(csv_dataset)
      Elsa.create_topic(@endpoints, topic)

      eventually(fn ->
        results = TestUtils.get_data_messages_from_kafka(topic, @endpoints)

        assert [%{payload: %{name: "Austin"}} | _] = results
      end)

      eventually(fn ->
        data_feed_status =
          Horde.Registry.lookup({:via, Horde.Registry, {Reaper.Registry, String.to_atom(dataset_id <> "_feed")}})

        assert data_feed_status == :undefined
      end)
    end
  end
end
