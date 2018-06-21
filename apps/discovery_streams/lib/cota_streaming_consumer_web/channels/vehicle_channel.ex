defmodule CotaStreamingConsumerWeb.VehicleChannel do
  use CotaStreamingConsumerWeb, :channel
  @cache Application.get_env(:cota_streaming_consumer, :cache)

  def join("vehicle_position", _params, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    Cachex.stream!(@cache)
    |> Stream.map(fn {:entry, _key, _create_ts, _ttl, message} -> message end)
    |> Enum.each(fn message -> push(socket, "update", message) end)

    {:noreply, socket}
  end
end
