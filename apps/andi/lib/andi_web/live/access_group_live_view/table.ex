defmodule AndiWeb.AccessGroupLiveView.Table do
  @moduledoc """
  LiveComponent for access group table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>">
      <table class="access-groups-table">
        <thead>
          <th class="access-groups-table__th access-groups-table__cell">Access Group</th>
          <th class="access-groups-table__th access-groups-table__cell">Modified Date</th>
          <th class="access-groups-table__th access-groups-table__cell">Action</th>
        </thead>

        <%= if @access_groups == [] do %>
          <tr><td class="access-groups-table__cell" colspan="100%">No Access Groups</td></tr>
        <% else %>
          <%= for access_group <- @access_groups do %>
          <tr class="access-groups-table__tr">
              <td class="access-groups-table__cell access-groups-table__cell--break access-groups-table__data-title-cell"><%= access_group["name"] %></td>
              <td class="access-groups-table__cell access-groups-table__cell--break"><%= format_modified_date(access_group["modified_date"]) %></td>
              <td class="access-groups-table__cell access-groups-table__cell--break" style="width: 10%;"><%= Link.link("Edit", to: "/access-groups/#{access_group["id"]}", class: "btn") %></td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end

  defp format_modified_date(datetime) do
    format = "{M}-{D}-{YYYY}"
    Timex.format!(datetime, format)
  end
end
