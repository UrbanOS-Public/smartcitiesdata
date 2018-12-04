defmodule CotaStreamingConsumerWeb.Presence.Instrumenter do
  @moduledoc false
  use Prometheus.Metric
  alias CotaStreamingConsumerWeb.Presence

  def setup do
    Gauge.declare(
      name: :cota_vehicle_positions_presence_count,
      help: "Number of socket connections."
    )
  end

  def record_count do
    count = Presence.connections("vehicle_position")

    [name: :cota_vehicle_positions_presence_count]
    |> Gauge.set(count)
  end
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
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](http://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.

  ## Usage

  Presences can be tracked in your channel after joining:

      defmodule CotaStreamingConsumer.MyChannel do
        use CotaStreamingConsumerWeb, :channel
        alias CotaStreamingConsumer.Presence

        def join("some:topic", _params, socket) do
          send(self, :after_join)
          {:ok, assign(socket, :user_id, ...)}
        end

        def handle_info(:after_join, socket) do
          push socket, "presence_state", Presence.list(socket)
          {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
            online_at: inspect(System.system_time(:seconds))
          })
          {:noreply, socket}
        end
      end

  In the example above, `Presence.track` is used to register this
  channel's process as a presence for the socket's user ID, with
  a map of metadata. Next, the current presence list for
  the socket's topic is pushed to the client as a `"presence_state"` event.

  Finally, a diff of presence join and leave events will be sent to the
  client as they happen in real-time with the "presence_diff" event.
  See `Phoenix.Presence.list/2` for details on the presence datastructure.

  ## Fetching Presence Information

  The `fetch/2` callback is triggered when using `list/1`
  and serves as a mechanism to fetch presence information a single time,
  before broadcasting the information to all channel subscribers.
  This prevents N query problems and gives you a single place to group
  isolated data fetching to extend presence metadata.

  The function receives a topic and map of presences and must return a
  map of data matching the Presence datastructure:

      %{"123" => %{metas: [%{status: "away", phx_ref: ...}],
        "456" => %{metas: [%{status: "online", phx_ref: ...}]}

  The `:metas` key must be kept, but you can extend the map of information
  to include any additional information. For example:

      def fetch(_topic, entries) do
        users = entries |> Map.keys() |> Accounts.get_users_map(entries)
        # => %{"123" => %{name: "User 123"}, "456" => %{name: nil}}

        for {key, %{metas: metas}} <- entries, into: %{} do
          {key, %{metas: metas, user: users[key]}}
        end
      end

  The function above fetches all users from the database who
  have registered presences for the given topic. The fetched
  information is then extended with a `:user` key of the user's
  information, while maintaining the required `:metas` field from the
  original presence data.
  """
  use Phoenix.Presence, otp_app: :cota_streaming_consumer,
                        pubsub_server: CotaStreamingConsumer.PubSub

  def connections(channel) do
    Phoenix.Presence.list(__MODULE__, channel)
    |> Map.keys()
    |> Enum.count()
  end
end
