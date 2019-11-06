defmodule AndiWeb.DatasetLiveView.Table do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="datasets-index__table">
      <table class="datasets-table">
        <thead>
          <th class="datasets-table__th datasets-table__cell">Organization</th>
          <th class="datasets-table__th datasets-table__cell">Dataset Name</th>
        </thead>
        <%= if @datasets == [] do %>
          <tr><td class="datasets-table__cell" colspan="100%">No Datasets Found</td></tr>
        <% else %>
          <%= for dataset <- @datasets do %>
          <tr class="datasets-table__tr">
            <td class="datasets-table__cell datasets-table__cell--break"><%= dataset.business.orgTitle %></td>
            <td class="datasets-table__cell datasets-table__cell--break"><%= dataset.business.dataTitle %></td>
          </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end
end
