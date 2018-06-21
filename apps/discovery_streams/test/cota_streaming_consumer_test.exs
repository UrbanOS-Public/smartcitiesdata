defmodule CotaStreamingConsumerTest do
  use CotaStreamingConsumerWeb.ChannelCase
  @cache Application.get_env(:cota_streaming_consumer, :cache)

  test "broadcasts data from a kafka topic to a websocket channel" do
    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

    CotaStreamingConsumer.handle_messages([
      create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}))
    ])

    assert_broadcast("update", %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}})
    leave(socket)
  end

  test "caches data from a kafka topic" do
    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

    CotaStreamingConsumer.handle_messages([
      create_message(~s({"vehicle":{"vehicle":{"id":"11603"}}}))
    ])

    assert(
      Cachex.stream!(@cache) |> Enum.to_list() |> Enum.map(fn{:entry, _key, _create_ts, _ttl, vehicle} -> vehicle end) == [
         %{"vehicle" => %{"vehicle" => %{"id" => "11603"}}}
      ]
    )

    leave(socket)
  end

  test "returns :ok after processing" do
    assert CotaStreamingConsumer.handle_messages([]) == :ok
  end

  defp create_message(data) do
    %{
      key: "some key",
      topic: "vehicle_position",
      value: data
    }
  end
end
