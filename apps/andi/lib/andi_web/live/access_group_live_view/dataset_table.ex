defmodule AndiWeb.AccessGroupLiveView.DatasetTable do
  @moduledoc """
  LiveComponent for access group datasets table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div class="access-group-datasets-results">
      <h2 class="component-title-text">Datasets Assigned to This Access Group</h2>
      <div class="access-groups-dataset-table-container">
        <table class="access-groups-dataset-table">
          <thead>
            <th class="access-groups-dataset-table__th access-groups-dataset-table__cell wide-column">Dataset</th>
            <th class="access-groups-dataset-table__th access-groups-dataset-table__cell wide-column">Organization</th>
            <th class="access-groups-dataset-table__th access-groups-dataset-table__cell wide-column">Keywords</th>
            <th class="access-groups-dataset-table__th access-groups-dataset-table__cell wide-column">Action</th>
          </thead>

          <%= if @selected_datasets == [] and @associated_datasets == [] do %>
            <tr><td class="access-groups-dataset-table__cell" colspan="100%">No Associated Datasets</td></tr>
          <% else %>
            <%= for dataset <- datasets_to_display(@associated_datasets, @selected_datasets) do %>
            <tr class="access-groups-dataset-table__tr">
                <td class="access-groups-dataset-table__cell access-groups-dataset-table__cell--break access-groups-dataset-table__data-title-cell wide-column"><%= dataset.business.dataTitle %></td>
                <td class="access-groups-dataset-table__cell access-groups-dataset-table__cell--break wide-column"><%= dataset.business.orgTitle %></td>
                <td class="access-groups-dataset-table__cell access-groups-dataset-table__cell--break wide-column"><%= Enum.join(dataset.business.keywords, ", ") %></td>
                <td class="access-groups-dataset-table__cell access-groups-dataset-table__cell--break modal-action-text thin-column" phx-click="remove-dataset" phx-value-id=<%= dataset.id %>>Remove</td>
              </tr>
            <% end %>
          <% end %>
        </table>
      </div>
    </div>
    """
  end

  defp datasets_to_display(associated_datasets, selected_dataset_ids) do
    associated_dataset_ids = Enum.map(associated_datasets, fn associated_dataset -> associated_dataset.id end)
    datasets_to_display = Enum.uniq(associated_dataset_ids ++ selected_dataset_ids)
    Enum.map(datasets_to_display, fn dataset_id -> Andi.InputSchemas.Datasets.get(dataset_id) end)
  end
end
