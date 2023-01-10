defmodule AndiWeb.OrganizationLiveView.HarvestedDatasetsTable do
  @moduledoc """
    LiveComponent for organization table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="organizations-index__table">
      <table class="organizations-table" title="Remote Datasets Attached To This Organization">
        <thead>
          <th class="organizations-table__th organizations-table__cell organizations-table__th--sortable organizations-table__th--<%= Map.get(@order, "data_title", "unsorted") %>" phx-click="order-by" phx-value-field="data_title" id="dataset-name">Dataset Name</th>
          <th class="organizations-table__th organizations-table__cell organizations-table__th--sortable organizations-table__th--<%= Map.get(@order, "source", "unsorted") %>" phx-click="order-by" phx-value-field="source">Source</th>
          <th class="organizations-table__th organizations-table__cell organizations-table__th--sortable organizations-table__th--<%= Map.get(@order, "modified_date", "unsorted") %>" phx-click="order-by" phx-value-field="modified_date">Modified Date</th>
          <th class="organizations-table__th organizations-table__cell" style="width: 10%">Actions</th>
          <th class="organizations-table__th organizations-table__cell">Include</th>
        </thead>

        <%= if @datasets == [] do %>
          <tr><td class="organizations-table__cell" colspan="100%" headers="dataset-name">No Datasets Found!</td></tr>
        <% else %>
          <%= for dataset <- @datasets do %>
            <tr class="organizations-table__tr">
              <td class="organizations-table__cell organizations-table__cell--break"><%= dataset["data_title"] %></td>
              <td class="organizations-table__cell organizations-table__cell--break"><%= dataset["source"] %></td>
              <td class="organizations-table__cell organizations-table__cell--break"><%= dataset["modified_date"] %></td>
              <td class="organizations-table__cell organizations-table__cell--break" style="width: 10%;"><%= Link.link("Edit", to: "/datasets/#{dataset["dataset_id"]}", class: "btn") %></td>
              <td class="organizations-table__cell organizations-table__cell--break" style="width: 1rem;">
              <label class="organizations-table__checkbox">
                <input class="organizations-table__checkbox--input" type="checkbox" phx-click="toggle_include" phx-value-id=<%= dataset["dataset_id"] %> <%= if dataset["include"], do: "checked" %>/>
              </label>
            </td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end
end
