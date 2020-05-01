defmodule EstuaryWeb.LiveViewHelper do
  @moduledoc false

  def filter_events(events, nil), do: events

  def filter_events(events, ""), do: events

  def filter_events(events, value) do
    Enum.filter(events, fn event ->
      search_contains?(event["author"], value) ||
        search_contains?(event["create_ts"], value) ||
        search_contains?(event["data"], value) ||
        search_contains?(event["type"], value)
    end)
  end

  defp search_contains?(event_field, search_str) when is_integer(event_field) do
    Integer.to_string(event_field)
    |> search_contains?(search_str)
  end

  defp search_contains?(event_field, search_str) do
    String.downcase(event_field) =~ String.downcase(search_str)
  end
end
