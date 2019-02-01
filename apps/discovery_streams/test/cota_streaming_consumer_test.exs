defmodule CotaStreamingConsumerTest do
  use CotaStreamingConsumerWeb.ChannelCase

  import Checkov
  import Mock
  import MockHelper
  import ExUnit.CaptureLog

  alias StreamingMetrics.ConsoleMetricCollector, as: MetricCollector

  @outbound_records "records"

  setup do
    Cachex.clear(:"cota-vehicle-positions")
    Cachex.clear(:"shuttle-position")
    :ok
  end

  data_test "broadcasts data from a kafka topic (#{topic}) to a websocket channel #{channel}" do
    with_mocks([
      {MetricCollector, [:passthrough], [record_metrics: fn _metrics, _namespace -> {:ok, %{}} end]}
      ])
    do
      {:ok, _, socket} =
        socket()
        |> subscribe_and_join(CotaStreamingConsumerWeb.StreamingChannel, channel)

      CotaStreamingConsumer.handle_messages([
        create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: topic)
      ])

      assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
      leave(socket)
    end

    where [
      [:channel,                     :topic],
      ["vehicle_position",           "cota-vehicle-positions"],
      ["streaming:shuttle-position", "shuttle-position"]
    ]
  end

  test "metrics are sent for a count of the uncached entities" do
    with_mocks([
      {MetricCollector, [:passthrough],
       [record_metrics: fn  [%{
        metric_name: @outbound_records,
        value: 1,
        unit: "Count",
        timestamp: _
       }], _namespace -> {:ok, %{}} end]}
    ])
    do
      {:ok, _, socket} =
        socket()
        |> subscribe_and_join(CotaStreamingConsumerWeb.StreamingChannel, "vehicle_position")

      CotaStreamingConsumer.handle_messages([
        create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: "cota-vehicle-positions"),
        create_message(~s({"vehicle_id": 34095, "description": "Some Description"}), topic: "shuttle-position")
      ])

      assert called_times(1, MetricCollector.record_metrics(:_, "cota_vehicle_positions"))
      assert called_times(1, MetricCollector.record_metrics(:_, "shuttle_position"))

      leave(socket)
    end
  end

  test "metrics fail to send" do
    with_mocks([
      {MetricCollector, [:passthrough], [record_metrics: fn _metrics, _namespace -> {:error, {:http_error, "reason"}}  end]}
      ])
    do
      {:ok, _, socket} =
        socket()
        |> subscribe_and_join(CotaStreamingConsumerWeb.StreamingChannel, "vehicle_position")

      assert capture_log([level: :warn], fn ->
        CotaStreamingConsumer.handle_messages([
          create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}), topic: "cota-vehicle-positions")
        ])
      end) =~ "Unable to write application metrics: {:http_error, \"reason\"}"

      leave(socket)
    end
  end

  test "caches data from a kafka topic" do
    with_mocks([
      {MetricCollector, [:passthrough],
       [record_metrics: fn _metrics, _namespace -> {:ok, %{}} end]}
    ])
    do
      {:ok, _, socket} =
        socket()
        |> subscribe_and_join(CotaStreamingConsumerWeb.StreamingChannel, "vehicle_position")

      CotaStreamingConsumer.handle_messages([
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
  end

  test "returns :ok after processing" do
    with_mocks([
      {MetricCollector, [:passthrough],
       [record_metrics: fn _metrics, _namespace -> {:ok, %{}} end]}
    ])
    do
      assert CotaStreamingConsumer.handle_messages([]) == :ok
    end
  end

  describe("integration") do

    test "Consumer properly invokes the \"count metric\" library function" do
      actual = capture_log(fn ->
        CotaStreamingConsumer.handle_messages([
          create_message(~s({"vehicle":{"vehicle":{"id":"11605"}}})),
          create_message(~s({"vehicle":{"vehicle":{"id":"11608"}}}))
        ])
      end)

      expected_outputs = ["metric_name: \"#{@outbound_records}\"",
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
