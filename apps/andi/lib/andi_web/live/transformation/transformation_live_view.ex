defmodule AndiWeb.TransformationLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-transformation" id="transformation-edit-page">

    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "user_id" => user_id} = _session, socket) do
    {:ok,
     assign(socket,
       is_curator: is_curator,
       user_id: user_id
     )}
  end

end
