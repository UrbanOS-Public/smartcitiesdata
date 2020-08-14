defmodule AndiWeb.OrganizationLiveView do
  use Phoenix.LiveView

  alias AndiWeb.OrganizationLiveView.Table

  def render(assigns) do
    ~L"""
    <div class="organizations-view">
      <div class="organizations-index">
        <div class="organizations-index__header">
          <h1 class="organizations-index__title">All Organizations</h1>
        </div>

        <div class="organizations-index__search">
          <form phx-change="search" phx-submit="search">
            <div class="organizations-index__search-input-container">
              <label for="organizations-index__search-input">
                <i class="material-icons organizations-index__search-icon">search</i>
              </label>
              <input
                name="search-value"
                phx-debounce="250"
                id="organizations-index__search-input"
                class="organizations-index__search-input"
                type="text"
                value="<%= @search_text %>"
                placeholder="Search Organizations"
              >
            </div>
          </form>
        </div>

        <%= live_component(@socket, Table, id: :organizations_table, organizations: @organizations, order: @order) %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       organizations: nil,
       search_text: nil,
       include_remotes: false,
       order: {"org_title", "asc"},
       params: %{}
     )}
  end

  def handle_params(params, _uri, socket) do
    order_by = Map.get(params, "order-by", "data_title")
    order_dir = Map.get(params, "order-dir", "asc")
    search_text = Map.get(params, "search", "")

    # view_models =
    #   filter_on_search_change(search_text, include_remotes, socket)
    #   |> sort_by_dir(order_by, order_dir)

    {:noreply,
     assign(socket,
       search_text: search_text,
       organizations: [],
       order: %{order_by => order_dir},
       params: params,
     )}
  end
end
