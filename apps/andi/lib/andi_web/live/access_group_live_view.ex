defmodule AndiWeb.AccessGroupLiveView do
  use AndiWeb, :live_view

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <div class="message">No Access Groups</div>
    """
  end
end
