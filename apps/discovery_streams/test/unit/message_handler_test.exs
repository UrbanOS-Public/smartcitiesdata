defmodule DiscoveryStreams.MessageHandlerTest do
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo

  import Checkov
  import ExUnit.CaptureLog

  alias DiscoveryStreams.{CachexSupervisor, MessageHandler, TopicSubscriber}
  alias SmartCity.TestDataGenerator, as: TDG

  @dataset_1_id "d21d5af6-346c-43e5-891f-8c2c7f28e4ab"
  @dataset_2_id "555ea731-d85e-4bd8-b2e4-4017366c24b0"

  setup do
    CachexSupervisor.create_cache(:"#{@dataset_1_id}")
    CachexSupervisor.create_cache(:"#{@dataset_2_id}")
    Cachex.clear(:"#{@dataset_1_id}")
    Cachex.clear(:"#{@dataset_2_id}")

    allow TopicSubscriber.list_subscribed_topics(),
      return: ["transformed-#{@dataset_1_id}", "transformed-#{@dataset_2_id}"]

    allow(Brook.get(any(), :streaming_datasets_by_id, @dataset_1_id),
      return: {:ok, "ceav__shuttles_on_a_map"}
    )

    allow(Brook.get(any(), :streaming_datasets_by_id, @dataset_2_id),
      return: {:ok, "central_ohio_transit_authority__cota_stream"}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, any()),
      return: {:error, "does_not_exist"}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, "ceav__shuttles_on_a_map"),
      return: {:ok, @dataset_1_id}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, "central_ohio_transit_authority__cota_stream"),
      return: {:ok, @dataset_2_id}
    )

    :ok
  end

  data_test "broadcasts data from a kafka topic (#{topic}) to a websocket channel #{channel}" do
    expect(TelemetryEvent.add_event_metrics(any(), [:records], value: %{count: any()}), return: :ok)

    {:ok, _, socket} =
      socket(DiscoveryStreamsWeb.UserSocket)
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, channel)

    MessageHandler.handle_messages([
      create_message(%{"vehicle" => %{"vehicle" => %{"id" => "11603"}}}, topic: topic)
    ])

    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    leave(socket)

    where([
      [:channel, :topic],
      ["streaming:central_ohio_transit_authority__cota_stream", "transformed-555ea731-d85e-4bd8-b2e4-4017366c24b0"],
      ["streaming:ceav__shuttles_on_a_map", "transformed-d21d5af6-346c-43e5-891f-8c2c7f28e4ab"]
    ])
  end

  test "unparsable messages are logged to the console without disruption" do
    expect(TelemetryEvent.add_event_metrics(any(), [:records], value: %{count: any()}), return: :ok)

    {:ok, _, socket} =
      socket(DiscoveryStreamsWeb.UserSocket)
      |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:ceav__shuttles_on_a_map")

    output =
      capture_log([level: :warn], fn ->
        MessageHandler.handle_messages([
          create_message(%{"vehicle" => %{"vehicle" => %{"id" => "11603"}}},
            topic: "transformed-d21d5af6-346c-43e5-891f-8c2c7f28e4ab"
          ),
          # <- Badly formatted JSON
          create_message(~s({"vehicle":{"vehicle":{"id:""11604"}}}),
            topic: "transformed-d21d5af6-346c-43e5-891f-8c2c7f28e4ab"
          ),
          create_message(%{"vehicle" => %{"vehicle" => %{"id" => "11605"}}},
            topic: "transformed-d21d5af6-346c-43e5-891f-8c2c7f28e4ab"
          )
        ])
      end)

    assert String.contains?(output, "Poison parse error") == true

    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11605"}}})

    leave(socket)
  end

  test "caches data from a kafka topic with one item per key" do
    expect(TelemetryEvent.add_event_metrics(any(), [:records], value: %{count: any()}), return: :ok)

    {:ok, _, socket} =
      socket(DiscoveryStreamsWeb.UserSocket)
      |> subscribe_and_join(
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:central_ohio_transit_authority__cota_stream"
      )

    msgs = %{
      a: %{"vehicle" => %{"vehicle" => %{"id" => "10000"}}},
      b: %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}},
      c: %{"vehicle" => %{"vehicle" => %{"id" => "99999"}}}
    }

    MessageHandler.handle_messages([
      create_message(msgs.a, key: "11604"),
      create_message(msgs.c, key: "11603")
    ])

    MessageHandler.handle_messages([
      create_message(msgs.b, key: "11604")
    ])

    cache_record_created = fn ->
      stream =
        Cachex.stream!(:"555ea731-d85e-4bd8-b2e4-4017366c24b0")
        |> Enum.to_list()
        |> Enum.map(fn {:entry, _key, _create_ts, _ttl, vehicle} -> vehicle end)

      Enum.all?([msgs.b, msgs.c], &Enum.member?(stream, &1))
    end

    Patiently.wait_for!(
      cache_record_created,
      dwell: 10,
      max_tries: 200
    )

    leave(socket)
  end

  defp create_message(%{} = data, opts) do
    create_message(TDG.create_data(payload: data) |> Jason.encode!(), opts)
  end

  defp create_message(data, opts) do
    %{
      key: Keyword.get(opts, :key, "some key"),
      topic: Keyword.get(opts, :topic, "transformed-555ea731-d85e-4bd8-b2e4-4017366c24b0"),
      value: data
    }
  end
end
