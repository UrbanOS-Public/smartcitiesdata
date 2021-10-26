defmodule DiscoveryStreamsWeb.StreamingChannel do
  @moduledoc """
    Handles websocket connections for streaming data.
    After a client joins the channel, it pushes the datasets cache to the client,
    and then begins sending new data as it arrives.
  """
  use DiscoveryStreamsWeb, :channel
  use Properties, otp_app: :discovery_streams
  require Logger

  getter(:raptor, generic: true)

  @instance_name DiscoveryStreams.instance_name()

  @update_event "update"
  @filter_event "filter"

  intercept([@update_event])

  def join(channel, params, socket) do

    system_name = determine_system_name(channel)

    case Brook.get(@instance_name, :streaming_datasets_by_system_name, system_name) do
      {:ok, nil} ->
        {:error, %{reason: "Channel #{channel} does not exist"}}

      {:ok, _dataset_id} ->
        api_key = params["api_key"]

        if is_authorized_in_raptor(api_key, system_name) do
          filter = Map.delete(params, "api_key")
          {:ok, assign(socket, :filter, create_filter_rules(filter))}
        else
          {:error, %{reason: "Unauthorized to connect to channel #{channel}"}}
        end

      _ ->
        {:error, %{reason: "Channel #{channel} does not exist"}}
    end
  end

  def is_authorized_in_raptor(api_key, system_name) do
    raptor_url = Keyword.fetch!(raptor(), :url)
    url_with_params = "#{raptor_url}?apiKey=#{api_key}&systemName=#{system_name}"
    case HTTPoison.get(url_with_params) do
      {:ok, %{body: body}} ->
        {:ok, is_authorized} = Jason.decode(body)
        is_authorized["is_authorized"]
      error ->
        Logger.error("Raptor failed to authorize with error: #{error}")
        false
    end
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
