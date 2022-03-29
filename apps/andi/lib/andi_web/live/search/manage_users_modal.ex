defmodule AndiWeb.Search.ManageUsersModal do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="manage-users-modal manage-users-modal--<%= @visibility %>">
      <div class="modal-form-container users-search-modal">
        <div class="search-index__header">
          <h1 class="search-index__title">User Search</h1>
        </div>

        <hr class="users-modal-divider">

        <div class="btn-group__standard">
          <button class="btn btn--large btn--action save-user-search" type="button" phx-click="save-user-search">Save</button>
        </div>
      </div>
    </div>
    """
  end

  # ~L"""
  # <div class="manage-datasets-modal manage-datasets-modal--<%= @visibility %>">
  #   <div class="modal-form-container dataset-search-modal">
  #     <div class="search-index__header">
  #       <h1 class="search-index__title">Dataset Search</h1>
  #     </div>

  #     <hr class="datasets-modal-divider">

  #     <p class="datasets-modal-helper-text">Search by dataset title, keywords, or organization.</p>

  #     <div class="datasets-modal__search">
  #         <p class="datasets-modal-section-header-text">Search</p>
  #         <form phx-change="dataset-search" phx-submit="dataset-search">
  #           <div class="datasets-modal__search-input-container">
  #             <label for="datasets-modal__search-input">
  #               <i class="material-icons datasets-modal__search-icon">search</i>
  #             </label>
  #             <input
  #               name="search-value"
  #               phx-debounce="250"
  #               id="datasets-modal__search-input"
  #               class="datasets-modal__search-input"
  #               type="text"
  #               value="<%= @search_text %>"
  #               placeholder="Search datasets"
  #             >
  #           </div>
  #         </form>
  #       </div>
  #     <div id="<%= @id %>">

  #   <div class="dataset-modal-search-results">
  #     <p class="datasets-modal-section-header-text">Results</p>
  #     <div class="dataset-modal-search-table">
  #       <table class="search-table">
  #         <thead>
  #           <th class="search-table__th search-table__cell wide-column">Dataset</th>
  #           <th class="search-table__th search-table__cell wide-column">Organization</th>
  #           <th class="search-table__th search-table__cell wide-column">Keywords</th>
  #           <th class="search-table__th search-table__cell thin-column">Action</th>
  #         </thead>

  #         <%= if @search_results == [] do %>
  #           <tr><td class="search-table__cell" colspan="100%">No Matching Datasets</td></tr>
  #         <% else %>
  #           <%= for dataset <- @search_results do %>
  #           <tr class="search-table__tr">
  #               <td class="search-table__cell search-table__cell--break search-table__data-title-cell wide-column"><%= dataset.business.dataTitle %></td>
  #               <td class="search-table__cell search-table__cell--break wide-column"><%= dataset.business.orgTitle %></td>
  #               <td class="search-table__cell search-table__cell--break wide-column"><%= Enum.join(dataset.business.keywords, ", ") %></td>
  #               <td class="search-table__cell search-table__cell--break modal-action-text thin-column" phx-click="select-dataset-search" phx-value-id=<%= dataset.id %>><%=selected_value(dataset.id, @selected_datasets)%></td>
  #             </tr>
  #           <% end %>
  #         <% end %>
  #       </table>
  #     </div>
  #   </div>
  # </div>

  # <div class="dataset-search-selected-datasets">
  #     <p class="datasets-modal-section-header-text">Selected Datasets</p>
  #     <div class="selected-datasets-from-search">
  #       <%= for dataset <- selected_datasets(@search_results, @selected_datasets) do %>
  #         <div class="selected-dataset-from-search"><span class="selected-dataset-text"><%= dataset.business.dataTitle %></span><i class="material-icons remove-selected-dataset" phx-click="remove-selected-dataset" phx-value-id=<%= dataset.id %>>close</i></div>
  #       <% end %>
  #     </div>
  # </div>

  # <hr class="datasets-modal-divider">

  # <div class="btn-group__standard">
  #       <button id="save-dataset-search-button" name="save-dataset-search-button" class="btn btn--large btn--action save-dataset-search" type="button" phx-click="save-dataset-search">Save</button>
  #     </div>
  #   </div>
  # </div>
  # """
  # end

  # def selected_datasets(datasets, selected_datasets) do
  #   Enum.map(selected_datasets, fn selected_dataset ->
  #     case Enum.find(datasets, fn dataset -> dataset.id == selected_dataset end) do
  #       nil -> Andi.InputSchemas.Datasets.get(selected_dataset)
  #       result -> result
  #     end
  #   end)
  # end

  # def selected_value(dataset_id, selected_datasets) do
  #   case dataset_id in selected_datasets do
  #     true -> "Remove"
  #     false -> "Select"
  #   end
  # end
end
