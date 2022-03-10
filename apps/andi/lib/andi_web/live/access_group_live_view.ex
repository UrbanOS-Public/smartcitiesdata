defmodule AndiWeb.AccessGroupLiveView do
  use AndiWeb, :live_view

  import Ecto.Query, only: [from: 2]

  alias AndiWeb.Router.Helpers, as: Routes
  # alias AndiWeb.AccessGroupLiveView.Table

  import AndiWeb.Helpers.SortingHelpers

  access_levels(render: [:private])

  @default_filters [
    include_remotes: false,
    only_submitted: false
  ]
  def render(assigns) do
    ~L"""
    <div></div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
    #   {:ok,
    #    assign(socket,
    #      datasets: nil,
    #      user_id: user_id,
    #      search_text: nil,
    #      include_remotes: default_for_filter(:include_remotes),
    #      only_submitted: default_for_filter(:only_submitted),
    #      is_curator: is_curator,
    #      order: {"data_title", "asc"},
    #      params: %{}
    #    )}
  end
end
