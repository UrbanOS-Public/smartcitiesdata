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
          <button type="button" class="btn btn--add-access-group btn--primary" phx-click="add-access-group">+ Add Access Group</button>
        </div>
        <p>Access Groups determine who is allowed to see datasets. If a dataset is restricted to one or more Access Groups, only the users in
        those groups may view the dataset.</p>

        <%= live_component(@socket, Table, id: :access_groups_table, access_groups: @view_models, is_curator: @is_curator) %>
      </div>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator} = _session, socket) do
    {:ok,
     assign(socket,
       is_curator: is_curator,
       access_groups: nil
     )}
  end

  def handle_params(_params, _uri, socket) do
    access_groups = Andi.InputSchemas.AccessGroups.get_all()
    view_models = access_groups |> convert_to_view_models()

    {:noreply,
     assign(socket,
       access_groups: access_groups,
       view_models: view_models
     )}
  end

  defp convert_to_view_models(access_groups) do
    Enum.map(access_groups, &to_view_model/1)
  end

  defp to_view_model(access_group) do
    %{
      "id" => access_group.id,
      "name" => access_group.name,
      "modified_date" => access_group.updated_at
    }
  end

  def handle_event("add-access-group", _, socket) do
    access_group = Andi.InputSchemas.AccessGroups.create()

    {:noreply, push_redirect(socket, to: "/access-groups/#{access_group.id}")}
  end
end
