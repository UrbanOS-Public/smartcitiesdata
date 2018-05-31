defmodule CotaStreamingConsumerWeb.VehicleChannel do
  use CotaStreamingConsumerWeb, :channel

  def join("vehicle_position", _params, socket) do
    {:ok, socket}
  end
end
