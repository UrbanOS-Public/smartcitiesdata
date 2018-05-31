defmodule CotaStreamingConsumerTest do
  use CotaStreamingConsumerWeb.ChannelCase

  test "broadcasts data from a kafka topic to a websocket channel" do
    {:ok, _, socket} =
      socket()
      |> subscribe_and_join(CotaStreamingConsumerWeb.VehicleChannel, "vehicle_position")

    CotaStreamingConsumer.handle_messages([
      create_message(~s({"vehicle": "one"})),
      create_message(~s({"vehicle": "two"}))
    ])

    assert_broadcast("update", %{"vehicle" => "one"})
    assert_broadcast("update", %{"vehicle" => "two"})
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
