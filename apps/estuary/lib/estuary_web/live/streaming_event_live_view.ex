defmodule EstuaryWeb.StreamingEventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.EventLiveView.Table

  @updated_event_stream "updated_event_stream"

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Events</h1>
      <%= live_component(@socket, Table, id: :events_table, events: @events, order: @order) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    EstuaryWeb.Endpoint.subscribe(@updated_event_stream)
    {:ok, assign(socket, events: [], order: {"create_ts", "desc"}, params: %{})}
  end

  def handle_info(%{topic: @updated_event_stream, payload: %{} = event}, socket) do
    updated_events =
      ([event] ++ socket.assigns.events)
      |> Enum.take(1000)
      |> Enum.sort(&(&1["create_ts"] >= &2["create_ts"]))

    {:noreply, assign(socket, :events, updated_events)}
  end
end
