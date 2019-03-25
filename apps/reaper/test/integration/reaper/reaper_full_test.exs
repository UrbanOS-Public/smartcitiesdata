defmodule Reaper.FullTest do
  use ExUnit.Case
  require Logger
  alias SmartCity.Dataset

  use Divo

  @kafka_endpoint Application.get_env(:kaffe, :producer)[:endpoints]
                  |> Enum.map(fn {k, v} -> {k, v} end)

  @destination_topic Application.get_env(:kaffe, :producer)
                     |> Keyword.get(:topics)
                     |> List.first()

  @pre_existing_dataset_id "00000-0000"

  @json_file_name "vehicle_locations.json"
  @gtfs_file_name "gtfs-realtime.pb"
  @csv_file_name "random_stuff.csv"

  @json_dataset_feed_record_count "test/support/#{@json_file_name}"
                                  |> File.read!()
                                  |> Reaper.Decoder.decode("json")
                                  |> Enum.count()
  @gtfs_dataset_feed_record_count "test/support/#{@gtfs_file_name}"
                                  |> File.read!()
                                  |> Reaper.Decoder.decode("gtfs")
                                  |> Enum.count()
  @csv_dataset_feed_record_count "test/support/#{@csv_file_name}"
                                 |> File.read!()
                                 |> Reaper.Decoder.decode("csv")
                                 |> Enum.count()

  setup_all do
    Redix.command(:redix, ["FLUSHALL"])
    bypass = Bypass.open()

    pre_existing_registry_message =
      FixtureHelper.new_registry_message(%{
        id: @pre_existing_dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "http://localhost:#{bypass.port}/#{@json_file_name}",
          sourceFormat: "json"
        }
      })

    bypass
    |> bypass_file(@json_file_name)
    |> bypass_file(@gtfs_file_name)
    |> bypass_file(@csv_file_name)

    Dataset.write(pre_existing_registry_message)

    {:ok, bypass: bypass}
  end

  test "configures and ingests a json-source that was added before reaper started", _context do
    wait_for_relative_offset(@destination_topic, @json_dataset_feed_record_count)

    vehicle_id =
      @destination_topic
      |> fetch_registry_feed_messages(@pre_existing_dataset_id)
      |> List.last()
      |> Map.get("vehicle_id")

    assert vehicle_id == 41_015
  end

  test "configures and ingests a gtfs source", %{
    bypass: bypass
  } do
    dataset_id = "12345-6789"

    gtfs_registry_message =
      FixtureHelper.new_registry_message(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "http://localhost:#{bypass.port}/#{@gtfs_file_name}",
          sourceFormat: "gtfs"
        }
      })

    Dataset.write(gtfs_registry_message)
    wait_for_relative_offset(@destination_topic, @gtfs_dataset_feed_record_count)

    vehicle_id =
      @destination_topic
      |> fetch_registry_feed_messages(dataset_id)
      |> List.first()
      |> Map.get("id")

    assert vehicle_id == "1004"
  end

  test "saves last_success_time to redis", %{
    bypass: bypass
  } do
    dataset_id = "12345-5555"

    gtfs_registry_message =
      FixtureHelper.new_registry_message(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "http://localhost:#{bypass.port}/#{@gtfs_file_name}",
          sourceFormat: "gtfs"
        }
      })

    Dataset.write(gtfs_registry_message)

    wait_for_relative_offset(@destination_topic, @gtfs_dataset_feed_record_count)

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

  test "configures and ingests a json source", %{
    bypass: bypass
  } do
    dataset_id = "23456-7891"

    json_registry_message =
      FixtureHelper.new_registry_message(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "http://localhost:#{bypass.port}/#{@json_file_name}",
          sourceFormat: "json"
        }
      })

    Dataset.write(json_registry_message)
    wait_for_relative_offset(@destination_topic, @json_dataset_feed_record_count)

    vehicle_id =
      @destination_topic
      |> fetch_registry_feed_messages(dataset_id)
      |> List.first()
      |> Map.get("vehicle_id")

    assert vehicle_id == 51_127
  end

  test "configures and ingests a csv source", %{
    bypass: bypass
  } do
    dataset_id = "34567-8912"

    csv_registry_message =
      FixtureHelper.new_registry_message(%{
        id: dataset_id,
        technical: %{
          cadence: 1_000,
          sourceUrl: "http://localhost:#{bypass.port}/#{@csv_file_name}",
          sourceFormat: "csv"
        }
      })

    Dataset.write(csv_registry_message)
    wait_for_relative_offset(@destination_topic, @csv_dataset_feed_record_count)

    person_name =
      @destination_topic
      |> fetch_registry_feed_messages(dataset_id)
      |> List.first()
      |> Map.get("name")

    assert person_name == "Erin"
  end

  defp wait_for_relative_offset(topic, count) do
    {:ok, last_offset} = :brod_utils.resolve_offset(@kafka_endpoint, topic, 0, -1, [])

    wait_for_absolute_offset(topic, last_offset + count)
  end

  defp wait_for_absolute_offset(topic, count) do
    Patiently.wait_for!(
      fn -> enough_offsets_seen?(topic, count) end,
      dwell: 2000,
      max_tries: 30
    )
  end

  defp enough_offsets_seen?(topic, count) do
    case :brod_utils.resolve_offset(@kafka_endpoint, topic, 0, -1, []) do
      {:ok, last_offset} ->
        last_offset == count

      _ ->
        false
    end
  end

  defp fetch_feed_messages(topic) do
    Stream.resource(
      fn -> 0 end,
      fn offset ->
        with {:ok, results} <- :brod.fetch(@kafka_endpoint, topic, 0, offset),
             {:kafka_message, current_offset, _headers?, _partition, _key, _body, _ts, _type,
              _ts_type} <-
               List.last(results) do
          {results, current_offset + 1}
        else
          _ -> {:halt, offset}
        end
      end,
      fn _ -> :unused end
    )
    |> Enum.map(fn {:kafka_message, _offset, _headers?, _partition, _key, body, _ts, _type,
                    _ts_type} ->
      Jason.decode!(body)
    end)
  end

  defp fetch_registry_feed_messages(topic, dataset_id) do
    topic
    |> fetch_feed_messages()
    |> Enum.filter(fn %{"dataset_id" => id} -> id == dataset_id end)
    |> Enum.map(fn %{"payload" => payload} -> payload end)
  end

  defp bypass_file(bypass, file_name) do
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
