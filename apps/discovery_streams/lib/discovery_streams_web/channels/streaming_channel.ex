defmodule DiscoveryStreamsWeb.StreamingChannel do
  @moduledoc """
    Handles websocket connections for streaming data.
    After a client joins the channel, it pushes the datasets cache to the client,
    and then begins sending new data as it arrives.
  """
  alias RaptorService

  use DiscoveryStreamsWeb, :channel
  use Properties, otp_app: :discovery_streams

  getter(:raptor_url, generic: true)

  @instance_name DiscoveryStreams.instance_name()

  @update_event "update"
  @filter_event "filter"

  intercept([@update_event])

  def join(channel, params, socket) do
    if String.downcase(System.get_env("REQUIRE_API_KEY")) == "true" do
      case Map.get(params, "api_key") do
        nil -> get_error_message(channel)
        api_key ->
          case RaptorService.get_user_id_from_api_key(raptor_url(), api_key) do
            {:ok, _user_id} ->
              is_authorized(channel, params, socket)

            {:error, reason, status_code} ->
              get_error_status(channel, reason, status_code)
          end
      end
    else
      is_authorized(channel, params, socket)
    end
  end

  defp is_authorized(channel, params, socket) do
    system_name = determine_system_name(channel)

    case Brook.get(@instance_name, :streaming_datasets_by_system_name, system_name) do
      {:ok, nil} -> get_error_message(channel)

      {:ok, _dataset_id} ->
        api_key = params["api_key"]

        if RaptorService.is_authorized(raptor_url(), api_key, system_name) do
          filter = Map.delete(params, "api_key")
          {:ok, assign(socket, :filter, create_filter_rules(filter))}
        else
          get_error_message(channel)
        end

      _ -> get_error_message(channel)
    end
  end

  defp get_error_message(channel), do: {:error, %{reason: "Channel #{channel} does not exist or you do not have access"}}

  def get_error_status(channel, reason, status_code), do: {:error, %{reason: "Channel #{channel} gave error code #{status_code} with reason #{reason}"}}

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
