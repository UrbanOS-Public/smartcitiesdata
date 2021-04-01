defmodule AndiWeb.EditUserLiveView.EditUserLiveViewTable do
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
          <th class="organizations-table__th organizations-table__cell organizations-table__th--sortable organizations-table__th--unsorted">Organization</th>
          <th class="organizations-table__th organizations-table__cell" style="width: 10%">Actions</th>
        </thead>

        <%= if @organizations == [] do %>
          <tr><td class="organizations-table__cell" colspan="100%">No Organizations Found!</td></tr>
        <% else %>
          <%= for organization <- @organizations do %>
            <tr class="organizations-table__tr">
              <td class="organizations-table__cell organizations-table__cell--break"><%= Map.get(organization, :orgName, "") %></td>
              <td class="organizations-table__cell organizations-table__cell--break" style="width: 10%;"><%= Link.link("Edit", to: "/organizations/#{Map.get(organization, :id)}", class: "btn") %></td>
            </td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end
end
