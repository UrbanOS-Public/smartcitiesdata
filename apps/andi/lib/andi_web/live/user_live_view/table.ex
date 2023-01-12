defmodule AndiWeb.UserLiveView.Table do
  @moduledoc """
    LiveComponent for user table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="users-index__table">
      <table class="users-table" title="All Users">
      <thead>
        <th class="users-table__th users-table__cell users-table__th--sortable users-table__th--<%= Map.get(@order, "email", "unsorted") %>" phx-click="order-by" phx-value-field="email">User Email</th>
        <th class="users-table__th users-table__cell">Actions</th>
        </thead>

        <%= if @users == [] do %>
          <tr><td class="users-table__cell" colspan="100%">No Users Found!</td></tr>
        <% else %>
          <%= for user <- @users do %>
          <tr class="users-table__tr">
            <td class="users-table__cell users-table__cell--break users-table__cell--email" style="width: 80%;"><%= user["email"] %></td>
            <td class="users-table__cell users-table__cell primary-color-link"><%= Link.link("Edit", to: "/user/#{user["id"]}", class: "btn") %></td>
          </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end
end
