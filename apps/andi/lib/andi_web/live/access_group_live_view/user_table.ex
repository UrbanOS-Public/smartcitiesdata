defmodule AndiWeb.AccessGroupLiveView.UserTable do
  @moduledoc """
  LiveComponent for access group users table
  """

  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="access-group-users-results">
      <h2 class="component-title-text">Users Assigned to This Access Group</h2>
      <div class="access-groups-sub-table-container">
        <table class="access-groups-sub-table" title="Users Assigned to This Access Group">
          <thead>
            <th class="access-groups-sub-table__th access-groups-sub-table__cell wide-column" id="name">Name</th>
            <th class="access-groups-sub-table__th access-groups-sub-table__cell wide-column">Email</th>
            <th class="access-groups-sub-table__th access-groups-sub-table__cell wide-column">Organizations</th>
            <th class="access-groups-sub-table__th access-groups-sub-table__cell thin-column">Actions</th>

          </thead>

          <%= if @selected_users == [] do %>
            <tr><td class="access-groups-sub-table__cell" colspan="100%" headers="name">No Associated Users</td></tr>
          <% else %>
            <%= for user <- users_to_display(@selected_users) do %>
            <tr class="access-groups-sub-table__tr">
                <td class="access-groups-sub-table__cell access-groups-sub-table__cell--break access-groups-sub-table__data-title-cell wide-column"><%= user.name %></td>
                <td class="access-groups-sub-table__cell access-groups-sub-table__cell--break wide-column"><%= user.email %></td>
                <td class="access-groups-sub-table__cell access-groups-sub-table__cell--break wide-column"><%= Enum.join(Enum.map(user.organizations, fn org -> org.orgTitle end), ", ") %></td>
                <td class="access-groups-sub-table__cell access-groups-sub-table__cell modal-action-text thin-column" phx-click="remove-selected-user" phx-value-id=<%= user.subject_id %>>Remove</td>
              </tr>
            <% end %>
          <% end %>
        </table>
      </div>
    </div>
    """
  end

  defp users_to_display(selected_users) do
    Enum.map(selected_users, fn user_id -> Andi.Schemas.User.get_by_subject_id(user_id) end)
  end
end
