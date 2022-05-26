defmodule AndiWeb.IngestionLiveView.SelectDatasetModal do
  use Phoenix.LiveComponent


  def render(assigns) do
    ~L"""
    <div class="manage-datasets-modal manage-datasets-modal--<%= @visibility %>">
      <div class="modal-form-container search-modal">
        <div class="search-index__header">
          <h1 class="search-index__title">Dataset Search</h1>
        </div>

        <hr class="search-modal-divider">

        <p class="search-modal-helper-text">Search by dataset title, keywords, or organization.</p>

        <div class="search-modal__search_bar">
          <p class="search-modal-section-header-text">Search</p>
          <form phx-change="datasets-search" phx-submit="datasets-search">
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
                placeholder="Search datasets"
              >
            </div>
          </form>
        </div>
        <div id="<%= @id %>">

        <div class="dataset-modal-search-results">
          <p class="search-modal-section-header-text">Results</p>
          <div class="search-modal-results-table">
            <table class="search-table">
              <thead>
                <th class="search-table__th search-table__cell wide-column">Dataset</th>
                <th class="search-table__th search-table__cell wide-column">Organization</th>
                <th class="search-table__th search-table__cell wide-column">Keywords</th>
                <th class="search-table__th search-table__cell thin-column">Action</th>
              </thead>

              <%= if @search_results == [] do %>
                <tr><td class="search-table__cell" colspan="100%">No Matching Datasets</td></tr>
              <% else %>
                <%= for dataset <- @search_results do %>
                <tr class="search-table__tr">
                    <td class="search-table__cell search-table__cell--break search-table__data-title-cell wide-column"><%= dataset.business.dataTitle %></td>
                    <td class="search-table__cell search-table__cell--break wide-column"><%= dataset.business.orgTitle %></td>
                    <td class="search-table__cell search-table__cell--break wide-column"><%= Enum.join(dataset.business.keywords, ", ") %></td>
                    <td class="search-table__cell search-table__cell--break modal-action-text thin-column" phx-click="select-dataset-search" phx-value-id=<%= dataset.id %>><%=selected_value(dataset.id, @selected_dataset)%></td>
                  </tr>
                <% end %>
              <% end %>
            </table>
          </div>
        </div>
      </div>

    <div class="dataset-search-selected-datasets">
        <p class="search-modal-section-header-text">Selected Datasets</p>
        <div class="selected-results-from-search">
          <%= if(selected_dataset(@search_results, @selected_dataset) == nil) do %>
            <div></div>
          <% else %>
            <div class="selected-result-from-search"><span class="selected-result-text"><%= get_dataset_name(@selected_dataset) %></span><i class="material-icons remove-selected-result" phx-click="remove-selected-dataset" phx-value-id=<%= @selected_dataset %>>close</i></div>
          <% end %>
        </div>
    </div>

    <hr class="search-modal-divider">

    <div class="btn-group__standard">
          <button id="save-dataset-search-button" name="save-dataset-search-button" class="btn btn--large btn--action save-search" type="button" phx-click="save-dataset-search">Save</button>
        </div>
      </div>
    </div>
    """
  end

  def selected_dataset(datasets, selected_dataset) do
    if(selected_dataset == nil) do
      nil
    else
      case Enum.find(datasets, fn dataset -> dataset.id == selected_dataset end) do
        nil -> Andi.InputSchemas.Datasets.get(selected_dataset)
        result -> result
      end
    end

  end

  def selected_value(dataset_id, selected_dataset) do
    case dataset_id == selected_dataset do
      true -> "Remove"
      false -> "Select"
    end
  end

  def get_dataset_name(id) do
    dataset = Andi.InputSchemas.Datasets.get(id)
    dataset.business.dataTitle
  end
end
