defmodule AndiWeb.AccessGroupLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  alias AndiWeb.AccessGroupLiveView.Table

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="access-groups-view">
      <div class="access-groups-index">
        <div class="access-groups-index__header">
          <h1 class="access-groups-index__title">Access Groups</h1>
          <button type="button" class="btn btn--add-access-group btn--action" phx-click="add-access-group">ADD ACCESS GROUP</button>
        </div>
        <p>Access Groups determine who is allowed to see datasets. If a dataset is restricted to one or more Access Groups, only the users in
        those groups may view the dataset.</p>

        <%= live_component(@socket, Table, id: :access_groups_table, access_groups: [], is_curator: @is_curator) %>
      </div>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator} = _session, socket) do
    {:ok,
     assign(socket,
       is_curator: is_curator
     )}
  end

  def handle_event("add-access-group", _, socket) do
    access_group = Andi.InputSchemas.AccessGroups.create()

    {:noreply, push_redirect(socket, to: "/access-groups/#{access_group.id}")}
  end
end
