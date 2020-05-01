defmodule EstuaryWeb.LiveViewHelper do
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

  defp search_contains?(str, search_str) when is_integer(str) do
    Integer.to_string(str)
    |> search_contains?(search_str)
  end

  defp search_contains?(str, search_str) do
    String.downcase(str) =~ String.downcase(search_str)
  end
end
