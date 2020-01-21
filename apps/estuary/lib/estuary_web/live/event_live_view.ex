defmodule EstuaryWeb.EventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.Router.Helpers, as: Routes
  alias EstuaryWeb.EventLiveView.Table

  @ingested_time_topic "ingested_time_topic"

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
      <%= live_component(@socket, Table, id: :events_table, events: @events, order: @order) %>
    </div>
    """
  end
end
