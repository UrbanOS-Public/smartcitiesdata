defmodule AndiWeb.EditUserLiveView.EditUserLiveViewRoleTable do
  @moduledoc """
    LiveComponent for user role table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="roles-index__table">
      <table class="roles-table">
        <thead>
          <th class="roles-table__th roles-table__cell roles-table__th--sortable roles-table__th--unsorted">Roles</th>
          <th class="roles-table__th roles-table__cell" style="width: 20%">Actions</th>
        </thead>

        <%= if @user_roles == [] do %>
          <tr><td class="roles-table__cell" colspan="100%">No Roles Found!</td></tr>
        <% else %>
          <%= for role <- @user_roles do %>
            <tr class="roles-table__tr">
              <td class="roles-table__cell roles-table__cell--break"><%= Map.get(role, "description", "") %></td>
              <td class="roles-table__cell roles-table__cell--break" style="width: 10%;">
                  <button phx-click="remove_role" phx-value-org-id="<%= role["id"] %>" phx-target="<%= @myself %>" class="btn btn--remove-organization">Remove</button>
              </td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end
end
