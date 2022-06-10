defmodule AndiWeb.IngestionLiveView.Table do
  @moduledoc """
  LiveComponent for ingestion table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>">
      <table class="ingestions-table">
        <thead>
          <th class="ingestions-table__th ingestions-table__cell">Status</th>
          <th class="ingestions-table__th ingestions-table__cell">Ingestion Name</th>
          <th class="ingestions-table__th ingestions-table__cell">Dataset</th>
          <th class="ingestions-table__th ingestions-table__cell">Action</th>
        </thead>

        <%= if @ingestions == [] do %>
          <tr><td class="ingestions-table__cell" colspan="100%">No Ingestions Found!</td></tr>
        <% else %>
          <%= for ingestion <- @ingestions do %>

            <tr class="ingestions-table__tr">
              <td class="ingestions-table__cell ingestions-table__cell--break ingestions-table__data-title-cell"><%= ingestion["status"] %></td>
              <td class="ingestions-table__cell ingestions-table__cell--break"><%= ingestion["ingestion_name"] %></td>
              <td class="ingestions-table__cell ingestions-table__cell--break"><%= ingestion["dataset_name"] %></td>
              <td class="ingestions-table__cell ingestions-table__cell--break" style="width: 10%;"><%= Link.link("Edit", to: "/ingestions/#{ingestion["id"]}", class: "btn") %></td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end
end
