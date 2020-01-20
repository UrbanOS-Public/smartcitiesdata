defmodule EstuaryWeb.EventLiveView do
  use Phoenix.LiveView
  alias EstuaryWeb.Router.Helpers, as: Routes
  alias EstuaryWeb.EventLiveView.Table

  @ingested_time_topic "ingested_time_topic"

  def render(assigns) do
    ~L"""
    <div class="datasets-index">
      <h1 class="datasets-index__title">All Events</h1>
      <div class="datasets-index__search">
        <form phx-change="search" phx-submit="search">
          <div class="datasets-index__search-input-container">
            <label for="datasets-index__search-input">
              <i class="material-icons datasets-index__search-icon">search</i>
            </label>
            <input
              name="search-value"
              phx-debounce="250"
              id="datasets-index__search-input"
              class="datasets-index__search-input"
              type="text"
              value="<%= @search_text %>"
              placeholder="Search datasets"
            >
          </div>
        </form>
      </div>
      <%= live_component(@socket, Table, id: :datasets_table, datasets: @datasets, order: @order) %>
    </div>
    """
  end
end
