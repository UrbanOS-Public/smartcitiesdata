defmodule AndiWeb.ErrorLiveView do
  use AndiWeb, :live_view

  access_levels(render: [:public, :private])

  def render(assigns) do
    ~L"""
    <div class="content">
      <main aria-label="Error Page" class="autherror-view">
        <div class="autherror-inner-content">
          <h3>Login Unsuccessful</h3>
          <p>You do not have permission to access this system.</p>
          <a href="/">Click here to return to login</a>
        </div>
      </main>
    </div>
    """
  end

  def mount(_params, socket) do
    {:ok, socket}
  end
end
