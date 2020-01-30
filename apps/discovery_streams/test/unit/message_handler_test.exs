defmodule DiscoveryStreams.MessageHandlerTest do
  use DiscoveryStreamsWeb.ChannelCase
  use Placebo

  import Checkov
  import ExUnit.CaptureLog

  alias StreamingMetrics.ConsoleMetricCollector, as: MetricCollector
  alias DiscoveryStreams.{CachexSupervisor, MessageHandler, TopicSubscriber}
  alias SmartCity.TestDataGenerator, as: TDG

  @outbound_records "records"
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

    allow(Brook.get(any(), :streaming_datasets_by_system_name, "ceav__shuttles_on_a_map"),
      return: {:ok, @dataset_1_id}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, "central_ohio_transit_authority__cota_stream"),
      return: {:ok, @dataset_2_id}
    )

    allow(Brook.get(any(), :streaming_datasets_by_system_name, any()),
      return: {:error, "does_not_exist"}
    )

    :ok
  end

  data_test "broadcasts data from a kafka topic (#{topic}) to a websocket channel #{channel}" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

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
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

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

  test "metrics are sent for a count of the uncached entities" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

    {:ok, _, socket} =
      socket(DiscoveryStreamsWeb.UserSocket)
      |> subscribe_and_join(
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:central_ohio_transit_authority__cota_stream"
      )

    MessageHandler.handle_messages([
      create_message(%{"vehicle" => %{"vehicle" => %{"id" => "11603"}}},
        topic: "transformed-555ea731-d85e-4bd8-b2e4-4017366c24b0"
      ),
      create_message(%{"vehicle_id" => "34095", "description" => "Some Description"},
        topic: "transformed-d21d5af6-346c-43e5-891f-8c2c7f28e4ab"
      )
    ])

    assert_called MetricCollector.record_metrics(any(), "transformed_555ea731_d85e_4bd8_b2e4_4017366c24b0"), once()
    assert_called MetricCollector.record_metrics(any(), "transformed_d21d5af6_346c_43e5_891f_8c2c7f28e4ab"), once()

    leave(socket)
  end

  test "metrics fail to send" do
    allow MetricCollector.record_metrics(any(), any()),
      return: {:error, {:http_error, "reason"}},
      meck_options: [:passthrough]

    {:ok, _, socket} =
      socket(DiscoveryStreamsWeb.UserSocket)
      |> subscribe_and_join(
        DiscoveryStreamsWeb.StreamingChannel,
        "streaming:central_ohio_transit_authority__cota_stream"
      )

    assert capture_log([level: :warn], fn ->
             MessageHandler.handle_messages([
               create_message(%{"vehicle" => %{"vehicle" => %{"id" => "11603"}}},
                 topic: "transformed-555ea731-d85e-4bd8-b2e4-4017366c24b0"
               )
             ])
           end) =~ "Unable to write application metrics: {:http_error, \"reason\"}"

    leave(socket)
  end

  test "caches data from a kafka topic with one item per key" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

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

  test "returns :ok after processing" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]
    assert MessageHandler.handle_messages([]) == :ok
  end

  describe("integration") do
    setup do
      previous_level = Logger.level()
      Logger.configure(level: :info)

      on_exit(fn -> Logger.configure(level: previous_level) end)
    end

    test "Consumer properly logs messages" do
      actual =
        capture_log(fn ->
          MessageHandler.handle_messages([
            create_message(%{"vehicle" => %{"vehicle" => %{"id" => "11605"}}}),
            create_message(%{"vehicle" => %{"vehicle" => %{"id" => "11608"}}})
          ])
        end)

      expected_outputs = [
        "metric_name: \"#{@outbound_records}\"",
        "value: 2",
        "unit: \"Count\"",
        ~r/dimensions: \[{\"PodHostname\", \"*\"/
      ]

      Enum.each(expected_outputs, fn x -> assert actual =~ x end)
    end
  end

  defp create_message(data, opts \\ [])

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
