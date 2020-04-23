defmodule EstuaryWeb.StreamingEventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.EventLiveView.Table

  @updated_event_stream "updated_event_stream"

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Streaming Events</h1>
      <%= live_component(@socket, Table, id: :events_table, events: @events, order: @order) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    EstuaryWeb.Endpoint.subscribe(@updated_event_stream)
    {:ok, assign(socket, events: nil, order: {"create_ts", "desc"}, params: %{})}
  end

  def handle_info(%{topic: @updated_event_stream, payload: %{events: events}}, socket) do
    updated_events =
      validate_events(events, socket.assigns.events)
      |> Enum.take(1000)
      |> Enum.sort(&(&1["create_ts"] >= &2["create_ts"]))

    {:noreply, assign(socket, :events, updated_events)}
  end

  defp validate_events(events, socket_events) do
    cond do
      events == nil and (socket_events == nil or socket_events == [nil]) -> nil
      events == nil -> socket_events
      socket_events == nil or socket_events == [nil] -> events
      true -> events ++ socket_events
    end
  end
end
