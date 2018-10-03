defmodule CotaStreamingConsumerWeb.VehicleChannel do
  use CotaStreamingConsumerWeb, :channel
  @cache Application.get_env(:cota_streaming_consumer, :cache)

  @update_event "update"
  @filter_event "filter"

  intercept([@update_event])

  def join("vehicle_position", params, socket) do
    send(self(), :after_join)
    {:ok, assign(socket, :filter, create_filter_rules(params))}
  end

  def handle_info(:after_join, socket = %{assigns: %{filter: filter}}) do
    push_cache_to_socket(socket, fn msg -> message_matches?(msg, filter) end)

    {:noreply, socket}
  end

  def handle_in(@filter_event, message, socket) do
    filter_rules = create_filter_rules(message)
    push_cache_to_socket(socket, fn msg -> message_matches?(msg, filter_rules) end)

    {:noreply, assign(socket, :filter, filter_rules)}
  end

  def handle_out(@update_event, message, socket = %{assigns: %{filter: filter}}) do
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

  defp push_cache_to_socket(socket, filter \\ fn _ -> true end) do
    query = Cachex.Query.create(true, :value)

    @cache
    |> Cachex.stream!(query)
    |> Stream.filter(filter)
    |> Enum.each(fn msg -> push(socket, @update_event, msg) end)
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
