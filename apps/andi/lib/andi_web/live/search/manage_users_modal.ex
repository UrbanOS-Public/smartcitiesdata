defmodule AndiWeb.Search.ManageUsersModal do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="manage-users-modal manage-users-modal--<%= @visibility %>">
      <div class="modal-form-container users-search-modal">
        <div class="search-index__header">
          <h1 class="search-index__title">User Search</h1>
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
                <th class="search-table__th search-table__cell wide-column">Email</th>
                <th class="search-table__th search-table__cell wide-column">Organizations</th>
                <th class="search-table__th search-table__cell thin-column">Action</th>
              </thead>

              <%= if @search_results == [] do %>
                <tr><td class="search-table__cell" colspan="100%">No Matching Users</td></tr>
              <% else %>
                <%= for user <- @search_results do %>
                <tr class="search-table__tr">
                    <td class="search-table__cell search-table__cell--break search-table__user-email-cell wide-column"><%= user.email %></td>
                    <td class="search-table__cell search-table__cell--break wide-column"><%= Enum.join(user.organizations, ", ") %></td>
                    <td></td>
                  </tr>
                <% end %>
              <% end %>
            </table>
          </div>
        </div>
      </div>

        <div class="btn-group__standard">
          <button class="btn btn--large btn--action save-search" type="button" phx-click="save-user-search">Save</button>
        </div>
      </div>
    </div>
    """
  end
end
