defmodule AndiWeb.AccessGroupLiveView.Table do
  @moduledoc """
  LiveComponent for access group table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  # TODO: This is copied from the datasets table. Make it access group.
  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="datasets-index__table">
      <table class="datasets-table">
        <thead>
          <th class="datasets-table__th datasets-table__cell datasets-table__status-cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@order, "status", "unsorted") %>" phx-click="order-by" phx-value-field="status">Status</th>
          <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@order, "data_title", "unsorted") %>" phx-click="order-by" phx-value-field="data_title">Dataset Name </th>
          <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@order, "org_title", "unsorted") %>" phx-click="order-by" phx-value-field="org_title">Organization </th>
          <th class="datasets-table__th datasets-table__cell">Actions</th>
        </thead>

        <%= if @datasets == [] do %>
          <tr><td class="datasets-table__cell" colspan="100%">No Datasets Found!</td></tr>
        <% else %>
          <%= for dataset <- @datasets do %>
            <% status = dataset["status"] %>
            <% status_modifier = get_status_class(status) %>

            <tr class="datasets-table__tr">
              <td class="datasets-table__cell datasets-table__cell--break dataset__status dataset__status--<%= status_modifier %>">
                <div class="status">
                  <div class="status__icon"></div>
                  <div class="status__message"><%= status %></div>
                </div>
              </td>
              <td class="datasets-table__cell datasets-table__cell--break datasets-table__data-title-cell"><%= dataset["data_title"] %></td>
              <td class="datasets-table__cell datasets-table__cell--break"><%= dataset["org_title"] %></td>
              <td class="datasets-table__cell datasets-table__cell--break" style="width: 10%;"><%= Link.link("Edit", to: "/#{edit_type(@is_curator)}/#{dataset["id"]}", class: "btn") %></td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end

  defp get_status_class(nil), do: "unset"
  defp get_status_class(status), do: String.downcase(status)

  defp edit_type(false), do: "submissions"
  defp edit_type(true), do: "datasets"
end
