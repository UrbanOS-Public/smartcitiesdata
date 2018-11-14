defmodule CotaStreamingConsumerTest do
  use CotaStreamingConsumerWeb.ChannelCase

  import Mock
  import MockHelper
  import ExUnit.CaptureLog

  alias StreamingMetrics.ConsoleMetricCollector, as: MetricCollector

  @cache Application.get_env(:cota_streaming_consumer, :cache)
  @outbound_records "Outbound Records"

  setup do
    Cachex.clear(@cache)
    :ok
  end

  test "broadcasts data from a kafka topic to a websocket channel" do
    with_mocks([
      {MetricCollector, [:passthrough], [record_metrics: fn _metrics, _namespace -> {:ok, %{}} end]}
      ])
    do
      {:ok, _, socket} =
        socket()
        |> subscribe_and_join(CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

      CotaStreamingConsumer.handle_messages([
        create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}))
      ])

      assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
      leave(socket)
    end
  end

  test "metrics are sent for a count of the uncached entities" do
    with_mocks([
      {MetricCollector, [:passthrough],
       [record_metrics: fn  [%{
        metric_name: "Outbound Records",
        value: 1,
        unit: "Count",
        timestamp: _
       }], _namespace -> {:ok, %{}} end]}
    ])
    do
      {:ok, _, socket} =
        socket()
        |> subscribe_and_join(CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

      CotaStreamingConsumer.handle_messages([
        create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}))
      ])

      assert called_times(1, MetricCollector.record_metrics(:_, "COTA Streaming"))
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
        |> subscribe_and_join(CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

      CotaStreamingConsumer.handle_messages([
        create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}))
      ])

      assert called_times(1, MetricCollector.record_metrics(:_, "COTA Streaming"))
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
        |> subscribe_and_join(CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

      CotaStreamingConsumer.handle_messages([
        create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}))
      ])

      cache_record_created = fn ->
        @cache
        |>Cachex.stream!()
        |> Enum.to_list()
        |> Enum.map(fn {:entry, _key, _create_ts, _ttl, vehicle} -> vehicle end) == [
          %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}}
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

  defp create_message(data) do
    %{
      key: "some key",
      topic: "vehicle_position",
      value: data
    }
  end
end
