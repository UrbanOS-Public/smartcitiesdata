defmodule CotaStreamingConsumerWeb.VehicleChannelTest do
  use CotaStreamingConsumerWeb.ChannelCase
  @cache Application.get_env(:cota_streaming_consumer, :cache)

  setup do
    Cachex.clear(@cache)
    :ok
  end

  test "sends the user the cache when they connect" do
    Cachex.put(@cache, "12342", %{"vehicleid" => "12342"})

    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

    assert_push("update", %{"vehicleid" => "12342"}, 1000)

    leave(socket)
  end
end
