defmodule EstuaryWeb.EventLiveView.Table do
  @moduledoc """
    LiveComponent for event_stream table
  """

  use Phoenix.LiveComponent
  import Phoenix.HTML
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="events-index__table">
      <table class="events-table">
      <thead>
        <th class="events-table__th events-table__cell events-table__th--sortable events-table__th--<%= Map.get(@order, "author", "unsorted") %>" phx-click="order-by" phx-value-field="author">Author </th>
        <th class="events-table__th events-table__cell events-table__th--sortable events-table__th--<%= Map.get(@order, "create_ts", "unsorted") %>" phx-click="order-by" phx-value-field="create_ts">Create Timestamp </th>
        <th class="events-table__th events-table__cell events-table__th--sortable events-table__th--<%= Map.get(@order, "data", "unsorted") %>" phx-click="order-by" phx-value-field="data">Data </th>
        <th class="events-table__th events-table__cell events-table__th--sortable events-table__th--<%= Map.get(@order, "type", "unsorted") %>" phx-click="order-by" phx-value-field="type">Type </th>
        </thead>

        <%= if @events == [] do %>
          <tr><td class="events-table__cell" colspan="100%">No events Found!</td></tr>
        <% end %>
      </table>
    </div>
    """
  end
end
