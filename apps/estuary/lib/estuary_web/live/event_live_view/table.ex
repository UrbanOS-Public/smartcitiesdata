defmodule EstuaryWeb.EventLiveView.Table do
  @moduledoc """
    LiveComponent for event_stream table
  """

  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="events-index__table">
      <table class="events-table">
      <thead>
        <th class="events-table__th events-table__cell" phx-value-field="author">Author </th>
        <th class="events-table__th events-table__cell" phx-value-field="create_ts">Create Timestamp </th>
        <th class="events-table__th events-table__cell" phx-value-field="data">Data </th>
        <th class="events-table__th events-table__cell" phx-value-field="type">Type </th>
      </thead>

        <%= if @events == [] do %>
          <tr><td class="events-table__cell" colspan="100%"><%= @no_events %></td></tr>
        <% else %>
          <%= for event <- @events do %>
            <tr class="events-table__tr">
              <td class="events-table__cell events-table__cell--break"><%= event["author"] %></td>
              <td class="events-table__cell events-table__cell--break"><%= event["create_ts"] %></td>
              <td class="events-table__cell events-table__cell--break"><%= event["data"] %></td>
              <td class="events-table__cell events-table__cell--break"><%= event["type"] %></td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end
end
