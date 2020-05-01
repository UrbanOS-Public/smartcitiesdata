defmodule EstuaryWeb.EventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.Router.Helpers, as: Routes
  alias EstuaryWeb.EventLiveView.Table
  alias Estuary.Services.EventRetrievalService
  alias EstuaryWeb.LiveViewHelper

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Events</h1>
      <div class="events-index__search">
        <form phx-change="search" phx-submit="search">
          <div class="events-index__search-input-container">
            <label for="events-index__search-input">
              <i class="material-icons events-index__search-icon">search</i>
            </label>
            <input
              name="search-value"
              phx-debounce="250"
              id="events-index__search-input"
              class="events-index__search-input"
              type="text"
              value="<%= @search_text %>"
              placeholder="Search events"
            >
          </div>
        </form>
      </div>
      <%= live_component(@socket, Table, id: :events_table, events: @events, no_events: @no_events) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, events} = EventRetrievalService.get_all()

    {:ok,
     assign(socket, events: events, no_events: "No Events Found!", search_text: nil, params: %{})}
  end

  def handle_params(params, _uri, socket) do
    {:ok, events} = EventRetrievalService.get_all()
    filtered_events = LiveViewHelper.filter_events(events, params["search"])

    {:noreply,
     assign(socket,
       search_text: params["search"],
       events: filtered_events,
       params: params
     )}
  end

  def handle_event("search", %{"search-value" => value}, socket) do
    search_params = Map.merge(socket.assigns.params, %{"search" => value})

    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, search_params))}
  end
end
