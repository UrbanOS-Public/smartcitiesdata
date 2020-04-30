defmodule EstuaryWeb.LiveViewHelper do
  def filter_on_search_change(search_value, socket) do
    case search_value == socket.assigns.search_text do
      false ->
        List.wrap(socket.assigns.events)
        |> refresh_events(search_value)

      _ ->
        socket.assigns.events
    end
  end

  def refresh_events(events, search_value) do
    events
    |> Enum.filter(&(!is_nil(&1)))
    |> filter_events?(search_value)
    |> Enum.take(1000)
    |> Enum.sort(&(&1["create_ts"] >= &2["create_ts"]))
  end

  defp filter_events?(events, nil), do: events

  defp filter_events?(events, ""), do: events

  defp filter_events?(events, value) do
    case is_list(events) do
      true -> filter_streaming_events(events, value)
      _ -> filter_events(events, value)
    end
  end

  defp filter_events(events, value) do
    Stream.filter(events, fn event ->
      search_contains?(event["author"], value) ||
        search_contains?(event["create_ts"], value) ||
        search_contains?(event["data"], value) ||
        search_contains?(event["type"], value)
    end)
  end

  defp filter_streaming_events(events, value) do
    Enum.filter(events, fn event ->
      search_contains?(event["author"], value) ||
        search_contains?(event["create_ts"], value) ||
        search_contains?(event["data"], value) ||
        search_contains?(event["type"], value)
    end)
  end

  defp search_contains?(str, search_str) when is_integer(str) do
    Integer.to_string(str)
    |> search_contains?(search_str)
  end

  defp search_contains?(str, search_str) do
    String.downcase(str) =~ String.downcase(search_str)
  end
end
