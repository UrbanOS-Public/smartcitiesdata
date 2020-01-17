defmodule EstuaryWeb.DatasetLiveView.Table do
  @moduledoc """
    LiveComponent for dataset table
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
        # <% else %>
        #   <%= for dataset <- @events do %>
        #   <tr class="events-table__tr">
        #     <td class="events-table__cell events-table__cell--break events-table__ingested-cell"><%= ingest_status(dataset) %></td>
        #     <td class="events-table__cell events-table__cell--break"><%= dataset["data_title"] %></td>
        #     <td class="events-table__cell events-table__cell--break"><%= dataset["org_title"] %></td>
        #     <td class="events-table__cell events-table__cell--break"><%= Link.link("Edit", to: "/events/#{dataset["id"]}", class: "btn") %></td>
        #   </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end

  def handle_event("order-by", %{"field" => field}, socket) do
    send(self(), {:order, field})
    {:noreply, socket}
  end

  defp ingest_status(dataset) do
    case dataset["ingested_time"] do
      nil -> ""
      _ -> ~E(<i class="material-icons">check</i>)
    end
  end
end
