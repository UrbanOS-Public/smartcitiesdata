defmodule CotaStreamingConsumerWeb.Presence.Instrumenter do
  @moduledoc false
  use Prometheus.Metric
  alias CotaStreamingConsumerWeb.Presence

  def setup do
    get_gauges()
    |> Map.keys()
    |> Enum.map(
      &Gauge.declare(
        name: &1,
        help: "Socket connections for #{&1}."
      )
    )
  end

  def record_count do
    get_gauges()
    |> Enum.map(fn {gauge, topic} ->
      count =
        topic
        |> topic_to_channel()
        |> Presence.connections()

      Gauge.set(gauge, count)
    end)
  end

  defp get_gauges do
    topics =
      Application.get_env(:kaffe, :consumer)
      |> Keyword.get(:topics, [])

    topics
    |> Enum.map(&String.replace(&1, "-", "_"))
    |> Enum.map(&String.to_atom("#{&1}_presence_count"))
    |> Enum.zip(topics)
    |> Enum.into(%{})
  end

  defp topic_to_channel("cota-vehicle-positions"), do: "vehicle_position"
  defp topic_to_channel(topic), do: "streaming:#{topic}"
end

defmodule CotaStreamingConsumerWeb.Presence.Server do
  @moduledoc """
  Push Phoenix presence metrics to our Prometheus gauge every 1 second.
  """

  use GenServer
  alias CotaStreamingConsumerWeb.Presence.Instrumenter

  def init(_) do
    Instrumenter.setup()
    tick()
    {:ok, []}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def handle_info(:tick, state) do
    Instrumenter.record_count()
    tick()
    {:noreply, state}
  end

  defp tick do
    Process.send_after(self(), :tick, 1000)
  end
end

defmodule CotaStreamingConsumerWeb.Presence do
  @moduledoc false
  use Phoenix.Presence,
    otp_app: :cota_streaming_consumer,
    pubsub_server: CotaStreamingConsumer.PubSub

  def connections(channel) do
    __MODULE__
    |> Phoenix.Presence.list(channel)
    |> Map.keys()
    |> Enum.count()
  end
end
