defmodule EstuaryWeb.StreamingEventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.Router.Helpers, as: Routes
  alias EstuaryWeb.EventLiveView.Table
  alias EstuaryWeb.LiveViewHelper
  alias Estuary.MessageHandler

  @updated_event_stream "updated_event_stream"

  def render(assigns) do
    ~L"""
    <div class="events-index">
      <h1 class="events-index__title">All Streaming Events</h1>
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
    EstuaryWeb.Endpoint.subscribe(@updated_event_stream)

    {:ok,
     assign(socket,
       events: [],
       no_events: "Waiting For The Events!",
       search_text: nil,
       params: %{}
     )}
  end

  def handle_info(%{topic: @updated_event_stream, payload: %{events: events}}, socket) do
    updated_events =
      (List.wrap(events) ++ List.wrap(socket.assigns.events))
      |> refresh_events(socket.assigns.search_text)

    {:noreply, assign(socket, :events, updated_events)}
  end

  def handle_params(params, _uri, socket) do
    filtered_events = refresh_events(socket.assigns.events, params["search"])

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

  defp refresh_events(events, search_value) do
    events
    |> Enum.filter(&(!is_nil(&1)))
    |> LiveViewHelper.filter_events(search_value)
    |> Enum.take(1000)
    |> Enum.sort(&(&1["create_ts"] >= &2["create_ts"]))
  end

  defp message_handler, do: Application.get_env(:estuary, :message_handler, MessageHandler)
end
