defmodule AndiWeb.EditUserLiveView.EditUserLiveViewTable do
  @moduledoc """
    LiveComponent for organization table
  """

  use Phoenix.LiveComponent
  alias Phoenix.HTML.Link

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="organizations-index__table">
      <table class="organizations-table" title="Organizations Associated With This User">
        <thead>
          <th class="organizations-table__th organizations-table__cell organizations-table__th--sortable organizations-table__th--unsorted">Organization</th>
          <th class="organizations-table__th organizations-table__cell" style="width: 20%">Actions</th>
        </thead>

        <%= if @organizations == [] do %>
          <tr><td class="organizations-table__cell" colspan="100%">No Organizations Found!</td></tr>
        <% else %>
          <%= for organization <- @organizations do %>
            <tr class="organizations-table__tr">
              <td class="organizations-table__cell organizations-table__cell--break"><%= Map.get(organization, :orgName, "") %></td>
              <td class="organizations-table__cell organizations-table__cell primary-color-link" style="width: 10%;">
                <%= Link.link("Edit", to: "/organizations/#{Map.get(organization, :id)}", class: "btn") %>
                <button phx-click="remove_org" phx-value-org-id="<%= organization.id %>" phx-target="<%= @myself %>" class="btn btn--remove-organization">Remove</button>
              </td>
            </td>
            </tr>
          <% end %>
        <% end %>
      </table>
    </div>
    """
  end

  def handle_event("remove_org", %{"org-id" => org_id}, socket) do
    send(self(), {:disassociate_org, org_id})
    {:noreply, socket}
  end
end
