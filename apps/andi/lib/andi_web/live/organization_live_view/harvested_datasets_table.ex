defmodule AndiWeb.OrganizationLiveView.HarvestedDatsetsTable do
  @moduledoc """
    LiveComponent for organization table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="organizations-index__table">
      <table class="organizations-table">
      <thead>
        <th class="organizations-table__th organizations-table__cell organizations-table__th--sortable organizations-table__th--<%= @order %>" phx-click="order-by" style="width: 80%">Dataset Name</th>
        <th class="organizations-table__th organizations-table__cell">Actions</th>
        <th class="organizations-table__th organizations-table__cell">Include</th>
        </thead>

        <%= if @datasets == [] do %>
          <tr><td class="organizations-table__cell" colspan="100%">No Datasets Found!</td></tr>
        <% else %>
          <%= for dataset <- @datasets do %>
            <% andi_dataset = Andi.InputSchemas.Datasets.get(dataset[:datasetId]) %>

              <tr class="organizations-table__tr">
              <td class="organizations-table__cell organizations-table__cell--break" style="width: 80%;"><%= get_in(andi_dataset, [:business, :dataTitle]) %></td>
              <td class="organizations-table__cell organizations-table__cell--break"><%= Link.link("Edit", to: "/datasets/#{andi_dataset[:id]}", class: "btn") %></td>
              <td>
                <label class="organizations-table__checkbox">
                  <input type="checkbox">
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
