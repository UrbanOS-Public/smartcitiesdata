defmodule AndiWeb.ReportsLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  use AndiWeb.FooterLiveView

  access_levels(render: [:private, :public])

  def render(assigns) do
    ~L"""
    <div class="content">
      <%= header_render(@is_curator, AndiWeb.HeaderLiveView.header_reports_path()) %>
      <main aria-label="Generate reports" class="report-view">
        <div class="report-index">
          <div class="report-index__header">
            <h1 class="report-index__title">Download Data Access Report</h1>
          </div>
          <p>This page will let you download a CSV with all current users and the datasets they have access to.</p>
          <hr class="report-line">
          <button type="button" class="btn btn--download" phx-click="">
            <span class="download-icon material-icons">file_download</span>
            Download Report
          </button>
        </div>
      </main>
      <%= footer_render(@is_curator) %>
    </div>
    """
  end

  def mount(_params, %{"user_id" => user_id, "is_curator" => is_curator} = _session, socket) do
    {:ok,
     assign(socket,
       user_id: user_id,
       is_curator: is_curator,
       params: %{}
     )}
  end
end
