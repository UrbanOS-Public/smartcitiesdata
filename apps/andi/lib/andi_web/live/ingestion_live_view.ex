defmodule AndiWeb.IngestionLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="ingestions-view">
      <div class="ingestions-index">
        <div class="ingestions-index__header">
          <h1 class="ingestions-index__title">All Data Ingestions</h1>
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
end
