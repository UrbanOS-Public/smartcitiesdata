defmodule DiscoveryStreams.TopicSubscriber do
  @moduledoc """
  Dynamically subscribes to Kafka topics.
  """
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
    (topics_we_should_be_consuming() -- list_subscribed_topics())
    |> subscribe()
  end

  defp topics_we_should_be_consuming() do
    case Brook.get_all_values(:discovery_streams, :streaming_datasets_by_system_name) do
      {:ok, items} ->
        Enum.map(items, &DiscoveryStreams.TopicHelper.topic_name(&1))

      {:error, _} ->
        Logger.warn("Unable to get values from Brook")
        []
    end
  end

  defp subscribe([]), do: nil

  # sobelow_skip ["DOS.StringToAtom"]
  defp subscribe(topics) do
    create_topics(topics)

    Logger.info("Subscribing to public topics: #{inspect(topics)}")
    Kaffe.GroupManager.subscribe_to_topics(topics)

    topics
    |> Enum.map(&DiscoveryStreams.TopicHelper.dataset_id/1)
    |> Enum.map(&String.to_atom/1)
    |> Enum.each(&CachexSupervisor.create_cache/1)
  end

  defp create_topics(topics) do
    Enum.each(topics, &Elsa.create_topic(DiscoveryStreams.TopicHelper.get_endpoints(), &1))
  end
end
