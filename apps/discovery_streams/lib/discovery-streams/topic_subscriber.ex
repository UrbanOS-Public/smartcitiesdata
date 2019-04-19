defmodule DiscoveryStreams.TopicSubscriber do
  @moduledoc false
  use GenServer
  require Logger

  alias DiscoveryStreams.CachexSupervisor

  @interval Application.get_env(:discovery_streams, :topic_subscriber_interval, 120_000)

  def start_link(_args) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  defdelegate list_subscribed_topics(), to: Kaffe.GroupManager

  def init(_args) do
    :timer.send_interval(@interval, :subscribe)
    {:ok, [], {:continue, :subscribe}}
  end

  def handle_continue(:subscribe, state) do
    check_for_new_topics_and_subscribe()
    {:noreply, state}
  end

  def handle_info(:subscribe, state) do
    check_for_new_topics_and_subscribe()
    {:noreply, state}
  end

  defp check_for_new_topics_and_subscribe() do
    (public_topics() -- list_subscribed_topics())
    |> subscribe()
  end

  defp subscribe([]), do: nil

  defp subscribe(topics) do
    Logger.info("Subscribing to public topics: #{inspect(topics)}")
    Kaffe.GroupManager.subscribe_to_topics(topics)

    topics
    |> Enum.map(&String.to_atom/1)
    |> Enum.each(&CachexSupervisor.create_cache/1)
  end

  defp get_endpoints() do
    Application.get_env(:kaffe, :consumer)[:endpoints]
    |> Enum.map(fn {host, port} -> {to_charlist(host), port} end)
  end

  defp public?(topic_metadata), do: not Keyword.get(topic_metadata, :is_internal)

  defp public_topics() do
    {:ok, metadata} = :brod.get_metadata(get_endpoints())

    metadata
    |> Keyword.get(:topic_metadata)
    |> Enum.filter(&public?/1)
    |> Enum.map(fn x -> Keyword.get(x, :topic) end)
  end
end
