defmodule Reaper.FullTest do
  use ExUnit.Case
  use Divo
  use Tesla
  use Placebo
  require Logger
  alias SmartCity.Dataset
  alias SmartCity.TestDataGenerator, as: TDG

  @kafka_endpoint Application.get_env(:kaffe, :producer)[:endpoints]
                  |> Enum.map(fn {k, v} -> {k, v} end)

  @destination_topic Application.get_env(:kaffe, :producer)[:topics]
                     |> List.first()

  @pre_existing_dataset_id "00000-0000"
  @partial_load_dataset_id "11111-1112"

  @json_file_name "vehicle_locations.json"
  @gtfs_file_name "gtfs-realtime.pb"
  @csv_file_name "random_stuff.csv"

  setup_all do
    bypass = Bypass.open()

    bypass
    |> bypass_file(@gtfs_file_name)
    |> bypass_file(@json_file_name)
    |> bypass_file(@csv_file_name)

    Patiently.wait_for!(
      fn ->
        {type, result} = get("http://localhost:#{bypass.port}/#{@json_file_name}")
        type == :ok and result.status == 200
      end,
      dwell: 1000,
      max_tries: 20
    )

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

      Dataset.write(pre_existing_dataset)
      :ok
    end

    test "configures and ingests a json-source that was added before reaper started" do
      expected = %{
        "latitude" => 39.9613,
        "vehicle_id" => 41_015,
        "update_time" => "2019-02-14T18:53:23.498889+00:00",
        "longitude" => -83.0074
      }

      Patiently.wait_for!(
        fn ->
          result =
            @pre_existing_dataset_id
            |> fetch_relevant_messages()
            |> List.last()

          result == expected
        end,
        dwell: 1000,
        max_tries: 20
      )
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
      :ok
    end

    test "configures and ingests a csv datasource that was partially loaded before reaper restarted", %{bypass: bypass} do
      expected = [
        %{"my_date" => "Spot", "my_int" => "1", "my_string" => "Austin"},
        %{"my_date" => "Bella", "my_int" => "2", "my_string" => "Erin"},
        %{"my_date" => "Max", "my_int" => "3", "my_string" => "Ben"}
      ]

      Patiently.wait_for!(
        fn ->
          result =
            @partial_load_dataset_id
            |> fetch_relevant_messages()

          result == expected
        end,
        dwell: 1000,
        max_tries: 20
      )
    end
  end

  describe "No pre-existing datasets" do
    setup do
      Redix.command(:redix, ["FLUSHALL"])
      :ok
    end

    test "configures and ingests a gtfs source", %{bypass: bypass} do
      dataset_id = "12345-6789"

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

      Patiently.wait_for!(
        fn ->
          result =
            dataset_id
            |> fetch_relevant_messages()
            |> List.first()

          case result do
            nil -> false
            message -> message["id"] == "1004"
          end
        end,
        dwell: 1000,
        max_tries: 20
      )
    end

    test "configures and ingests a json source", %{bypass: bypass} do
      dataset_id = "23456-7891"

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

      Patiently.wait_for!(
        fn ->
          result =
            dataset_id
            |> fetch_relevant_messages()
            |> List.first()

          case result do
            nil -> false
            message -> message["vehicle_id"] == 51_127
          end
        end,
        dwell: 1000,
        max_tries: 20
      )
    end

    test "configures and ingests a csv source", %{bypass: bypass} do
      dataset_id = "34567-8912"

      csv_dataset =
        TDG.create_dataset(%{
          id: dataset_id,
          technical: %{
            cadence: 1_000,
            sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
            sourceFormat: "csv",
            sourceType: "batch",
            schema: [%{name: "id"}, %{name: "name"}, %{name: "pet"}]
          }
        })

      Dataset.write(csv_dataset)

      Patiently.wait_for!(
        fn ->
          result =
            dataset_id
            |> fetch_relevant_messages()
            |> List.first()

          case result do
            nil -> false
            message -> message["name"] == "Austin"
          end
        end,
        dwell: 1000,
        max_tries: 20
      )

      assert false == File.exists?(dataset_id)
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

      Patiently.wait_for!(
        fn ->
          result = Redix.command!(:redix, ["GET", "reaper:derived:#{dataset_id}"])
          result != nil
        end,
        dwell: 1000,
        max_tries: 20
      )

      result =
        Redix.command!(:redix, ["GET", "reaper:derived:#{dataset_id}"])
        |> Jason.decode!()

      result["timestamp"]
      |> DateTime.from_iso8601()
      |> case do
        {:ok, date_time_from_redis, _} ->
          assert DateTime.diff(date_time_from_redis, DateTime.utc_now()) < 5

        _ ->
          flunk("Should have put a valid DateTime into redis")
      end
    end
  end

  describe "One time Batch" do
    setup do
      Redix.command(:redix, ["FLUSHALL"])
      :ok
    end

    test "cadence of once is only processed once", %{bypass: bypass} do
      dataset_id = "only-once"

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

      # The data is written to kafka
      Patiently.wait_for!(
        fn ->
          result =
            dataset_id
            |> fetch_relevant_messages()
            |> List.last()

          case result do
            nil -> false
            message -> message["name"] == "Ben"
          end
        end,
        dwell: 1000,
        max_tries: 40
      )

      Patiently.wait_for!(
        fn ->
          data_feed_status =
            Horde.Registry.lookup({:via, Horde.Registry, {Reaper.Registry, String.to_atom(dataset_id <> "_feed")}})

          data_feed_status == :undefined
        end,
        dwell: 100,
        max_tries: 20
      )
    end
  end

  defp fetch_relevant_messages(dataset_id) do
    @destination_topic
    |> fetch_all_feed_messages()
    |> Enum.filter(fn %{"dataset_id" => id} -> id == dataset_id end)
    |> Enum.map(fn %{"payload" => payload} -> payload end)
  end

  defp fetch_all_feed_messages(topic) do
    Stream.resource(
      fn -> 0 end,
      fn offset ->
        with {:ok, results} <- :brod.fetch(@kafka_endpoint, topic, 0, offset),
             {:kafka_message, current_offset, _headers?, _partition, _key, _body, _ts, _type, _ts_type} <-
               List.last(results) do
          {results, current_offset + 1}
        else
          _ -> {:halt, offset}
        end
      end,
      fn _ -> :unused end
    )
    |> Enum.map(fn {:kafka_message, _offset, _headers?, _partition, _key, body, _ts, _type, _ts_type} ->
      Jason.decode!(body)
    end)
  end

  defp bypass_file(bypass, file_name) do
    Bypass.stub(bypass, "HEAD", "/#{file_name}", fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    Bypass.stub(bypass, "GET", "/#{file_name}", fn conn ->
      Plug.Conn.resp(
        conn,
        200,
        File.read!("test/support/#{file_name}")
      )
    end)

    bypass
  end
end
