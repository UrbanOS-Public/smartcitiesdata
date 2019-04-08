defmodule CotaStreamingConsumer.MessageHandlerTest do
  use CotaStreamingConsumerWeb.ChannelCase
  use Placebo

  import Checkov
  import ExUnit.CaptureLog

  alias StreamingMetrics.ConsoleMetricCollector, as: MetricCollector
  alias CotaStreamingConsumer.{CachexSupervisor, MessageHandler}

  @outbound_records "records"

  setup do
    CachexSupervisor.create_cache(:"cota-vehicle-positions")
    CachexSupervisor.create_cache(:"shuttle-position")
    Cachex.clear(:"cota-vehicle-positions")
    Cachex.clear(:"shuttle-position")
    :ok
  end

  data_test "broadcasts data from a kafka topic (#{topic}) to a websocket channel #{channel}" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(CotaStreamingConsumerWeb.StreamingChannel, channel)

    MessageHandler.handle_messages([
      create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: topic)
    ])

    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    leave(socket)

    where([
      [:channel, :topic],
      ["vehicle_position", "cota-vehicle-positions"],
      ["streaming:cota-vehicle-positions", "cota-vehicle-positions"],
      ["streaming:shuttle-position", "shuttle-position"]
    ])
  end

  test "unparsable messages are logged to the console without disruption" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(CotaStreamingConsumerWeb.StreamingChannel, "streaming:shuttle-position")

    assert capture_log([level: :warn], fn ->
             MessageHandler.handle_messages([
               create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: "shuttle-position"),
               # <- Badly formatted JSON
               create_message(~s({"vehicle":{"vehicle":{"id:""11604"}}}), topic: "shuttle-position"),
               create_message(~s({"vehicle":{"vehicle":{"id":"11605"}}}), topic: "shuttle-position")
             ])
           end) =~ ~S(Poison parse error: {:invalid, "\"", 28)

    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11605"}}})

    leave(socket)
  end

  test "metrics are sent for a count of the uncached entities" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(CotaStreamingConsumerWeb.StreamingChannel, "vehicle_position")

    MessageHandler.handle_messages([
      create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: "cota-vehicle-positions"),
      create_message(~s({"vehicle_id": 34095, "description": "Some Description"}), topic: "shuttle-position")
    ])

    assert_called MetricCollector.record_metrics(any(), "cota_vehicle_positions"), once()
    assert_called MetricCollector.record_metrics(any(), "shuttle_position"), once()

    leave(socket)
  end

  test "metrics fail to send" do
    allow MetricCollector.record_metrics(any(), any()),
      return: {:error, {:http_error, "reason"}},
      meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(CotaStreamingConsumerWeb.StreamingChannel, "vehicle_position")

    assert capture_log([level: :warn], fn ->
             MessageHandler.handle_messages([
               create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: "cota-vehicle-positions")
             ])
           end) =~ "Unable to write application metrics: {:http_error, \"reason\"}"

    leave(socket)
  end

  test "caches data from a kafka topic" do
    allow MetricCollector.record_metrics(any(), any()), return: {:ok, %{}}, meck_options: [:passthrough]

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(CotaStreamingConsumerWeb.StreamingChannel, "vehicle_position")

    MessageHandler.handle_messages([
      create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), key: "11604")
    ])

    cache_record_created = fn ->
      Cachex.stream!(:"cota-vehicle-positions")
      |> Enum.to_list()
      |> Enum.map(fn {:entry, key, _create_ts, _ttl, vehicle} -> {key, vehicle} end) == [
        {"11604", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}}}
      ]
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
    test "Consumer properly invokes the \"count metric\" library function" do
      actual =
        capture_log(fn ->
          MessageHandler.handle_messages([
            create_message(~s({"vehicle":{"vehicle":{"id":"11605"}}})),
            create_message(~s({"vehicle":{"vehicle":{"id":"11608"}}}))
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

  defp create_message(data, opts \\ []) do
    %{
      key: Keyword.get(opts, :key, "some key"),
      topic: Keyword.get(opts, :topic, "cota-vehicle-positions"),
      value: data
    }
  end
end
