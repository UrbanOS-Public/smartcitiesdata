defmodule AndiWeb.Search.AddDatasetModal do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="add-dataset-modal add-dataset-modal--<%= @visibility %>">
      <div class="modal-form-container">
        <div class="search-index__header">
          <h1 class="search-index__title">Dataset Search</h1>
        </div>
        <p>Search by dataset title, keywords, or organization.</p>

        <div class="datasets-index__search">
            <form phx-change="search" phx-submit="search">
              <div class="datasets-index__search-input-container">
                <label for="datasets-index__search-input">
                  <i class="material-icons datasets-index__search-icon">search</i>
                </label>
                <input
                  name="search-value"
                  phx-debounce="250"
                  id="datasets-index__search-input"
                  class="datasets-index__search-input"
                  type="text"
                  value="<%= @search_text %>"
                  placeholder="Search datasets"
                >
              </div>
            </form>
          </div>
        <div id="<%= @id %>">

      <table class="search-table">
        <thead>
          <th class="search-table__th search-table__cell">Dataset</th>
          <th class="search-table__th search-table__cell">Organization</th>
          <th class="search-table__th search-table__cell">Keywords</th>
        </thead>

        <%= if @datasets == [] do %>
          <tr><td class="search-table__cell" colspan="100%">No Matching Datasets</td></tr>
        <% else %>
          <%= for dataset <- @datasets do %>
          <tr class="search-table__tr">
              <td class="search-table__cell search-table__cell--break search-table__data-title-cell"><%= dataset.business.dataTitle %></td>
              <td class="search-table__cell search-table__cell--break"><%= dataset.business.orgTitle %></td>
              <td class="search-table__cell search-table__cell--break"><%= dataset.business.keywords %></td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    <div class="btn-group__standard">
          <button type="button" class="btn btn--small btn--cancel cancel-search" phx-click="cancel-search">Cancel</button>
          <button id="save-search-button" name="save-search-button" class="btn btn--save btn--small save-search" type="button" phx-click="save-search">Save</button>
        </div>
      </div>
    </div>
    """
  end
end
