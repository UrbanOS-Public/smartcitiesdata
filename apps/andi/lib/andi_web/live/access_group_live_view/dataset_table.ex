defmodule AndiWeb.AccessGroupLiveView.DatasetTable do
  @moduledoc """
  LiveComponent for access group datasets table
  """

  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="access-group-datasets-results">
      <h2 class="component-title-text">Datasets Assigned to This Access Group</h2>
      <div class="access-groups-sub-table-container">
        <table class="access-groups-sub-table" title="Datasets Assigned to This Access Group">
          <thead>
            <th class="access-groups-sub-table__th access-groups-sub-table__cell wide-column">Dataset</th>
            <th class="access-groups-sub-table__th access-groups-sub-table__cell wide-column">Organization</th>
            <th class="access-groups-sub-table__th access-groups-sub-table__cell wide-column">Keywords</th>
            <th class="access-groups-sub-table__th access-groups-sub-table__cell wide-column">Action</th>
          </thead>

          <%= if @selected_datasets == [] do %>
            <tr><td class="access-groups-sub-table__cell" colspan="100%">No Associated Datasets</td></tr>
          <% else %>
            <%= for dataset <- datasets_to_display(@selected_datasets) do %>
            <tr class="access-groups-sub-table__tr">
                <td class="access-groups-sub-table__cell access-groups-sub-table__cell--break access-groups-sub-table__data-title-cell wide-column"><%= dataset.business.dataTitle %></td>
                <td class="access-groups-sub-table__cell access-groups-sub-table__cell--break wide-column"><%= dataset.business.orgTitle %></td>
                <td class="access-groups-sub-table__cell access-groups-sub-table__cell--break wide-column"><%= Enum.join(dataset.business.keywords, ", ") %></td>
                <td class="access-groups-sub-table__cell access-groups-sub-table__cell  thin-column">
                  <a class="modal-action-text" href="javascript:void(0)" phx-click="remove-selected-dataset" phx-value-id=<%= dataset.id %>>Remove</a>
                </td>
              </tr>
            <% end %>
          <% end %>
        </table>
      </div>
    </div>
    """
  end

  defp datasets_to_display(selected_datasets) do
    Enum.map(selected_datasets, fn dataset_id -> Andi.InputSchemas.Datasets.get(dataset_id) end)
  end
end
