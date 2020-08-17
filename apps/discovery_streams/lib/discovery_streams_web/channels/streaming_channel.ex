defmodule DiscoveryStreamsWeb.StreamingChannel do
  @moduledoc """
    Handles websocket connections for streaming data.
    After a client joins the channel, it pushes the datasets cache to the client,
    and then begins sending new data as it arrives.
  """
  use DiscoveryStreamsWeb, :channel
  alias DiscoveryStreams.TopicSubscriber
  alias DiscoveryStreams.TopicHelper

  @update_event "update"
  @filter_event "filter"

  intercept([@update_event])

  def join(channel, params, socket) do
    topic = determine_topic(channel)
    IO.inspect(channel, label: "channel is")
    # case topic in
    #   false ->
    #     {:error, %{reason: "Channel #{channel} does not exist"}}

    # true ->
    send(self(), :after_join)
    {:ok, assign(socket, :filter, create_filter_rules(params))}
    # end
  end

  def handle_info(:after_join, %{assigns: %{filter: _filter}} = socket) do
    {:noreply, socket}
  end

  def handle_in(@filter_event, message, socket) do
    filter_rules = create_filter_rules(message)

    {:noreply, assign(socket, :filter, filter_rules)}
  end

  def handle_out(@update_event, message, %{assigns: %{filter: filter}} = socket) do
    if message_matches?(message, filter) do
      push(socket, @update_event, message)
    end

    {:noreply, socket}
  end

  def handle_out(@update_event, message, socket) do
    push(socket, @update_event, message)
    {:noreply, socket}
  end

  defp create_filter_rules(message) do
    Enum.map(message, fn {key, value} ->
      {String.split(key, "."), value}
    end)
  end

  # sobelow_skip ["DOS.StringToAtom"]
  defp determine_system_name("streaming:" <> system_name), do: system_name

  defp determine_topic("streaming:" <> system_name) do
    get_dataset_id(system_name)
    |> TopicHelper.topic_name()
  end

  defp determine_topic(channel) do
    determine_system_name(channel)
    |> get_dataset_id()
    |> TopicHelper.topic_name()
  end

  defp get_dataset_id(system_name) do
    case Brook.get(:discovery_streams, :streaming_datasets_by_system_name, system_name) do
      {:ok, dataset_id} -> dataset_id
      _ -> nil
    end
  end

  defp message_matches?(message, filter) do
    Enum.all?(filter, fn {field, value} -> field_matches?(message, field, value) end)
  end

  defp field_matches?(message, field, value_list) when is_list(value_list) do
    Enum.any?(value_list, fn value -> value == get_in(message, field) end)
  end

  defp field_matches?(message, field, value) do
    get_in(message, field) == value
  end
end
