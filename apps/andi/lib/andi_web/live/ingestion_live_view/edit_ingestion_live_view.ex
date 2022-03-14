defmodule AndiWeb.IngestionLiveView.EditIngestionLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  import Phoenix.HTML.Form

  access_levels(render: [:private])


  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    """
  end

  def mount(_params, %{"is_curator" => is_curator} = _session, socket) do
    {:ok,
     assign(socket,
       is_curator: is_curator
     )}
  end

end
