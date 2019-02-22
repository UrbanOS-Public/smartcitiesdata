defmodule Reaper.FullTest do
  use ExUnit.Case
  require Logger
  alias Kaffe.Producer

  @kafka_endpoint Application.get_env(:kaffe, :consumer)[:endpoints]
                  |> Enum.map(fn {k, v} -> {k, v} end)

  @webserver_host Application.get_env(:reaper, :webserver_host, "localhost")
  @webserver_port Application.get_env(:reaper, :webserver_port, "7000")

  @source_topic Application.get_env(:kaffe, :consumer)
                |> Keyword.get(:topics)
                |> List.first()

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
  @total_dataset_feed_record_count @json_dataset_feed_record_count * 2 + @gtfs_dataset_feed_record_count +
                                     @csv_dataset_feed_record_count

  setup_all do
    pre_existing_dataset =
      FixtureHelper.new_dataset(%{
        id: @pre_existing_dataset_id,
        operational: %{
          cadence: 1_000,
          sourceUrl: "http://#{@webserver_host}:#{@webserver_port}/#{@json_file_name}",
          sourceFormat: "json"
        }
      })

    Application.ensure_all_started(:kaffe)
    Producer.produce_sync(@source_topic, "does-not-matter", Jason.encode!(pre_existing_dataset))
    wait_for_absolute_offset(@source_topic, 1)

    Application.ensure_all_started(:reaper)
    on_exit(fn -> Application.stop(:reaper) end)
    wait_for_relative_offset(@destination_topic, @json_dataset_feed_record_count)

    :ok
  end

  test "configures and ingests a json-source that was added before reaper started" do
    vehicle_id =
      @destination_topic
      |> fetch_dataset_feed_messages(@pre_existing_dataset_id)
      |> List.last()
      |> Map.get("vehicle_id")

    assert vehicle_id == 41_015
  end

  test "configures and ingests a gtfs source" do
    dataset_id = "12345-6789"

    gtfs_dataset =
      FixtureHelper.new_dataset(%{
        id: dataset_id,
        operational: %{
          cadence: 1_000,
          sourceUrl: "http://#{@webserver_host}:#{@webserver_port}/#{@gtfs_file_name}",
          sourceFormat: "gtfs"
        }
      })

    Producer.produce_sync(@source_topic, "does-not-matter", Jason.encode!(gtfs_dataset))
    wait_for_relative_offset(@destination_topic, @gtfs_dataset_feed_record_count)

    vehicle_id =
      @destination_topic
      |> fetch_dataset_feed_messages(dataset_id)
      |> List.first()
      |> Map.get("id")

    assert vehicle_id == "1004"
  end

  test "configures and ingests a json source" do
    dataset_id = "23456-7891"

    json_dataset =
      FixtureHelper.new_dataset(%{
        id: dataset_id,
        operational: %{
          cadence: 1_000,
          sourceUrl: "http://#{@webserver_host}:#{@webserver_port}/#{@json_file_name}",
          sourceFormat: "json"
        }
      })

    Producer.produce_sync(@source_topic, "does-not-matter", Jason.encode!(json_dataset))
    wait_for_relative_offset(@destination_topic, @json_dataset_feed_record_count)

    vehicle_id =
      @destination_topic
      |> fetch_dataset_feed_messages(dataset_id)
      |> List.first()
      |> Map.get("vehicle_id")

    assert vehicle_id == 51_127
  end

  test "configures and ingests a csv source" do
    dataset_id = "34567-8912"

    csv_dataset =
      FixtureHelper.new_dataset(%{
        id: dataset_id,
        operational: %{
          cadence: 1_000,
          sourceUrl: "http://#{@webserver_host}:#{@webserver_port}/#{@csv_file_name}",
          sourceFormat: "csv"
        }
      })

    Producer.produce_sync(@source_topic, "does-not-matter", Jason.encode!(csv_dataset))
    wait_for_relative_offset(@destination_topic, @csv_dataset_feed_record_count)

    person_name =
      @destination_topic
      |> fetch_dataset_feed_messages(dataset_id)
      |> List.first()
      |> Map.get("name")

    assert person_name == "Erin"
  end

  test "starts at the beginning after a restart/start" do
    Application.stop(:reaper)
    Application.ensure_all_started(:reaper)

    wait_for_relative_offset(@destination_topic, @total_dataset_feed_record_count)

    assert @destination_topic |> fetch_feed_messages() |> Enum.count() == @total_dataset_feed_record_count * 2
  end

  defp wait_for_relative_offset(topic, count) do
    {:ok, last_offset} = :brod_utils.resolve_offset(@kafka_endpoint, topic, 0, -1, [])

    wait_for_absolute_offset(topic, last_offset + count)
  end

  defp wait_for_absolute_offset(topic, count) do
    Patiently.wait_for!(
      fn -> enough_offsets_seen?(topic, count) end,
      dwell: 1000,
      max_tries: 20
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

  defp fetch_dataset_feed_messages(topic, dataset_id) do
    topic
    |> fetch_feed_messages()
    |> Enum.filter(fn %{"metadata" => %{"dataset_id" => id}} -> id == dataset_id end)
    |> Enum.map(fn %{"payload" => payload} -> payload end)
  end
end
