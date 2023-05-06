defmodule AndiWeb.IngestionLiveView.Table do
  @moduledoc """
  LiveComponent for ingestion table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>">
      <table class="ingestions-table" title="All Data Ingestions">
        <thead>
          <th class="ingestions-table__th ingestions-table__cell ingestions-table__status-cell">Status</th>
          <th class="ingestions-table__th ingestions-table__cell" id="ingestion-name">Ingestion Name</th>
          <th class="ingestions-table__th ingestions-table__cell">Dataset</th>
          <th class="ingestions-table__th ingestions-table__cell">Action</th>
        </thead>

        <%= if @ingestions == [] do %>
          <tr><td class="ingestions-table__cell" colspan="100%" headers="ingestion-name">No Ingestions Found!</td></tr>
        <% else %>
          <%= for ingestion <- @ingestions do %>
          <% status_success_class = if ingestion["status"] == "Published", do: "ingestion__status--success", else: ""%>

            <tr class="ingestions-table__tr">
              <td class="ingestions-table__cell ingestions-table__cell--break ingestion__status <%= status_success_class %>">
                <div class="status">
                  <div class="status__icon"></div>
                  <div class="status__message"><%= ingestion["status"] %></div>
                </div>
              </td>
              <td class="ingestions-table__cell ingestions-table__cell--break"><%= ingestion["ingestion_name"] %></td>
              <td class="ingestions-table__cell ingestions-table__cell--break"><%= ingestion["dataset_names"] %></td>
              <td class="ingestions-table__cell ingestions-table__cell--break primary-color-link" style="width: 10%;"><%= Link.link("Edit", to: "/ingestions/#{ingestion["id"]}", class: "btn") %></td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end
end
