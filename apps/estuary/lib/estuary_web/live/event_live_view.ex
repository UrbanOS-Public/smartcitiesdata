defmodule EstuaryWeb.EventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.EventLiveView.Table
  alias Estuary.Services.EventRetrievalService

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Events</h1>
      <%= live_component(@socket, Table, id: :events_table, events: @events, no_events: @no_events) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, events} = EventRetrievalService.get_all()
    IO.inspect(Enum.to_list(events), label: "StreamEventsToList")
    {:ok, assign(socket, events: events, no_events: "No Events Found!")}
  end
end
