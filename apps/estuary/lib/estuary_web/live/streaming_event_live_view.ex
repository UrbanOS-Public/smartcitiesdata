defmodule EstuaryWeb.StreamingEventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.EventLiveView.Table

  @updated_event_stream "updated_event_stream"

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Streaming Events</h1>
      <%= live_component(@socket, Table, id: :events_table, events: @events, no_events: @no_events, order: @order) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    EstuaryWeb.Endpoint.subscribe(@updated_event_stream)

    {:ok,
     assign(socket,
       events: [],
       no_events: "Waiting For The Events!",
       order: {"create_ts", "desc"},
       params: %{}
     )}
  end

  def handle_info(%{topic: @updated_event_stream, payload: %{events: events}}, socket) do
    updated_events =
      (List.wrap(events) ++ List.wrap(socket.assigns.events))
      |> Enum.filter(&(!is_nil(&1)))
      |> Enum.take(1000)
      |> Enum.sort(&(&1["create_ts"] >= &2["create_ts"]))

    {:noreply, assign(socket, :events, updated_events)}
  end
end
