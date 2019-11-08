defmodule AndiWeb.DatasetLiveView do
  use Phoenix.LiveView
  alias AndiWeb.Router.Helpers, as: Routes
  alias AndiWeb.DatasetLiveView.Table

  def render(assigns) do
    ~L"""
    <div class="datasets-index">
      <h1 class="datasets-index__title">All Datasets</h1>
      <div class="datasets-index__search">
        <form phx-change="search" phx-submit="search">
          <label for="datasets-index__search">
          Search:
          <input
            name="search-value"
            phx-debounce="250"
            class="datasets-search"
            type="text"
            id="datasets-index__search"
            value="<%= @search_text %>"
          >
          </label>
        </form>
      </div>
      <%= live_component(@socket, Table, datasets: @datasets) %>
    </div>
    """
  end

  def mount(_session, socket) do
    {:ok, assign(socket, datasets: nil, search_text: "")}
  end

  def handle_params(params, _uri, socket) do
    search_text = Map.get(params, "search-value", "")
    datasets = Andi.DatasetCache.get_datasets()

    {:noreply, assign(socket, search_text: search_text, datasets: filter_datasets(datasets, search_text))}
  end

  def handle_event("search", %{"search-value" => value}, socket) do
    {:noreply, live_redirect(socket, to: Routes.live_path(socket, __MODULE__, %{"search-value": value}))}
  end

  # Private Functions
  defp filter_datasets(datasets, ""), do: datasets

  defp filter_datasets(datasets, value) do
    Enum.filter(datasets, fn dataset ->
      search_contains?(dataset.business.orgTitle, value) || search_contains?(dataset.business.dataTitle, value)
    end)
  end

  defp search_contains?(str, search_str) do
    String.downcase(str) =~ String.downcase(search_str)
  end
end
