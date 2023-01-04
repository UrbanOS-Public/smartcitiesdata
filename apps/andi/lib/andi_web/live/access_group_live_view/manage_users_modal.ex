defmodule AndiWeb.AccessGroupLiveView.ManageUsersModal do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="manage-users-modal manage-users-modal--<%= @visibility %>">
      <div class="modal-form-container search-modal" x-trap="<%= @visibility === "visible" %>">
        <div class="search-index__header">
          <h1 class="search-index__title">User Search</h1>
          <button type="button" class="btn btn--transparent material-icons search-index__exit" phx-click="cancel-manage-users">close</button>
        </div>

        <hr class="search-modal-divider">

        <p class="search-modal-helper-text">Search by user name, email, or organization.</p>

        <div class="search-modal__search_bar">
          <p class="search-modal-section-header-text">Search</p>
          <form phx-change="user-search" phx-submit="user-search">
            <div class="search-modal__search_bar-input-container">
              <label for="search-modal__search_bar-input">
                <i class="material-icons search-modal__search_bar-icon">search</i>
              </label>
              <input
                name="search-value"
                phx-debounce="250"
                id="search-modal__search_bar-input"
                class="search-modal__search_bar-input"
                type="text"
                value="<%= @search_text %>"
                placeholder="Search users"
              >
            </div>
          </form>
        </div>

        <div class="user-modal-search-results">
          <p class="search-modal-section-header-text">Results</p>
          <div class="search-modal-results-table">
            <table class="search-table">
              <thead>
                <th class="search-table__th search-table__cell wide-column">Name</th>
                <th class="search-table__th search-table__cell wide-column">Email</th>
                <th class="search-table__th search-table__cell wide-column">Organizations</th>
                <th class="search-table__th search-table__cell thin-column">Action</th>
              </thead>

              <%= if @search_results == [] do %>
                <tr><td class="search-table__cell" colspan="100%">No Matching Users</td></tr>
              <% else %>
                <%= for user <- @search_results do %>
                <tr class="search-table__tr">
                    <td class="search-table__cell search-table__cell--break search-table__user-name-cell wide-column"><%= user.name %></td>
                    <td class="search-table__cell search-table__cell--break search-table__user-email-cell wide-column"><%= user.email %></td>
                    <td class="search-table__cell search-table__cell--break wide-column"><%= pretty_print_orgs(user.organizations) %></td>
                    <td class="search-table__cell search-table__cell--break thin-column">
                      <a class="modal-action-text" href="javascript:void(0)" phx-click="select-user-search" phx-value-id=<%= user.subject_id %>><%=selected_value(user.subject_id, @selected_users)%></a>
                    </td>
                    <td></td>
                  </tr>
                <% end %>
              <% end %>
            </table>
          </div>
        </div>

        <div class="user-search-selected-users">
          <p class="search-modal-section-header-text">Selected Users</p>
          <div class="selected-results-from-search">
            <%= for user <- selected_users(@search_results, @selected_users) do %>
              <div class="selected-result-from-search">
                <span class="selected-result-text"><%= user.name %></span>
                <button type="button" class="btn btn--transparent material-icons remove-selected-result" phx-click="remove-selected-user" phx-value-id=<%= user.subject_id %>>close</button>
              </div>
            <% end %>
          </div>
        </div>

        <hr class="search-modal-divider">

        <div class="btn-group__standard">
          <button class="btn btn--primary-outline btn--large save-search" type="button" phx-click="save-user-search">Save</button>
        </div>
      </div>
    </div>
    """
  end

  defp pretty_print_orgs(organizations) do
    organizations
    |> Enum.map(fn org -> org.orgTitle end)
    |> Enum.join(", ")
  end

  def selected_users(users, selected_users) do
    Enum.map(selected_users, fn selected_user ->
      case Enum.find(users, fn user -> user.subject_id == selected_user end) do
        nil -> Andi.Schemas.User.get_by_subject_id(selected_user)
        result -> result
      end
    end)
  end

  def selected_value(user_id, selected_users) do
    case user_id in selected_users do
      true -> "Remove"
      false -> "Select"
    end
  end
end
