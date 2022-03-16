defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  import Phoenix.HTML.Form

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-page" id="access-groups-edit-page">
    <div class="edit-page__btn-group">
        <div class="btn-group__standard">
          <button type="button" class="btn btn--large btn--cancel" phx-click="cancel-edit">Cancel</button>
        </div>

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

  def handle_event("cancel-edit", _, socket) do
       {:noreply, redirect(socket, to: header_access_groups_path())}
    
  end
end
