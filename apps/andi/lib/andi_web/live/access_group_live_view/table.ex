defmodule AndiWeb.AccessGroupLiveView.Table do
  @moduledoc """
  LiveComponent for access group table
  """

  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>">
      <table class="access-groups-table">
        <thead>
          <th class="access-groups-table__th access-groups-table__cell">Access Group</th>
          <th class="access-groups-table__th access-groups-table__cell">Modified Date</th>
          <th class="access-groups-table__th access-groups-table__cell">Action</th>
        </thead>

        <tr><td class="access-groups-table__cell" colspan="100%">No Access Groups</td></tr>
      </table>
    </div>
    """
  end
end
