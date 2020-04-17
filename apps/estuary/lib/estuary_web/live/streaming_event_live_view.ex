defmodule EstuaryWeb.StreamingEventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.EventLiveView.StreamingTable

  @updated_event_stream "updated_event_stream"

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Events</h1>
      <%= live_component(@socket, StreamingTable, id: :events_table, events: @events, order: @order) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    EstuaryWeb.Endpoint.subscribe(@updated_event_stream)
    {:ok, assign(socket, events: nil, order: {"create_ts", "asc"}, params: %{})}
  end

  def handle_info(
        %{topic: @updated_event_stream, event: @updated_event_stream, payload: %{}},
        socket
      ) do
    # updated_events = update_event_stream(create_ts, socket.assigns.events)
    # updated_state = assign(socket, :events, updated_events)

    # {:noreply, updated_state}
  end

  defp update_event_stream(create_ts, events) do
    exisiting_index = Enum.find_index(events, fn event -> create_ts == event["create_ts"] end)

    case is_nil(exisiting_index) do
      true ->
        events

      _ ->
        updated_event =
          events
          |> Enum.at(exisiting_index)
          |> Map.put("create_ts", create_ts)

        List.replace_at(events, exisiting_index, updated_event)
    end
  end
end
