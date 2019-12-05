defmodule AndiWeb.DatasetLiveView.Table do
  @moduledoc """
    LiveComponent for dataset table
  """

  use Phoenix.LiveComponent
  import Phoenix.HTML
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="datasets-index__table">
      <table class="datasets-table">
      <thead>
        <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@order, "ingested_time", "unsorted") %>" phx-click="order-by" phx-value-field="ingested_time">Ingested </th>
        <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@order, "data_title", "unsorted") %>" phx-click="order-by" phx-value-field="data_title">Dataset Name </th>
        <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@order, "org_title", "unsorted") %>" phx-click="order-by" phx-value-field="org_title">Organization </th>
        <th class="datasets-table__th datasets-table__cell">Actions</th>
        </thead>

        <%= if @datasets == [] do %>
          <tr><td class="datasets-table__cell" colspan="100%">No Datasets Found!</td></tr>
        <% else %>
          <%= for dataset <- @datasets do %>
          <tr class="datasets-table__tr">
            <td class="datasets-table__cell datasets-table__cell--break datasets-table__ingested-cell"><%= ingest_status(dataset) %></td>
            <td class="datasets-table__cell datasets-table__cell--break"><%= dataset["data_title"] %></td>
            <td class="datasets-table__cell datasets-table__cell--break"><%= dataset["org_title"] %></td>
            <td class="datasets-table__cell datasets-table__cell--break"><%= Link.link("Edit", to: "/datasets/#{dataset["id"]}", class: "btn") %></td>
          </tr>
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
