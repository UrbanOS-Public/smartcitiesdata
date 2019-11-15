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
          <div class="datasets-index__search-input-container">
            <label for="datasets-index__search-input">
              <i class="material-icons datasets-index__search-icon">search</i>
            </label>
            <input
              name="search-value"
              phx-debounce="250"
              id="datasets-index__search-input"
              class="datasets-index__search-input"
              type="text"
              value="<%= @search_text %>"
              placeholder="Search datasets"
            >
          </div>
        </form>
      </div>
      <%= live_component(@socket, Table, id: :datasets_table, datasets: @datasets, order: @order) %>
    </div>
    """
  end

  def mount(_session, socket) do
    {:ok, assign(socket, datasets: nil, search_text: nil, order: {"data_title", "asc"}, params: %{})}
  end

  def handle_info({:order, field}, socket) do
    order_dir =
      case socket.assigns.order do
        %{^field => "asc"} -> "desc"
        _ -> "asc"
      end

    params = Map.merge(socket.assigns.params, %{"order-by" => field, "order-dir" => order_dir})

    {:noreply, live_redirect(socket, to: Routes.live_path(socket, __MODULE__, params))}
  end

  def handle_params(params, _uri, socket) do
    order_by = Map.get(params, "order-by", "data_title")
    order_dir = Map.get(params, "order-dir", "asc")
    search_text = Map.get(params, "search", "")

    view_models =
      filter_on_search_change(search_text, socket)
      |> sort_by_dir(order_by, order_dir)

    {:noreply,
     assign(socket, search_text: search_text, datasets: view_models, order: %{order_by => order_dir}, params: params)}
  end

  def handle_event("search", %{"search-value" => value}, socket) do
    search_params = Map.merge(socket.assigns.params, %{"search" => value})
    {:noreply, live_redirect(socket, to: Routes.live_path(socket, __MODULE__, search_params))}
  end

  defp filter_on_search_change(search_value, socket) do
    case search_value == socket.assigns.search_text do
      false -> Andi.DatasetCache.get_all() |> filter_models(search_value) |> Enum.map(&to_view_model/1)
      _ -> socket.assigns.datasets
    end
  end

  defp filter_models(models, ""), do: models

  defp filter_models(models, value) do
    Enum.filter(models, fn model ->
      search_contains?(model.dataset.business.orgTitle, value) ||
        search_contains?(model.dataset.business.dataTitle, value)
    end)
  end

  defp search_contains?(str, search_str) do
    String.downcase(str) =~ String.downcase(search_str)
  end

  defp sort_by_dir(models, order_by, order_dir) do
    case order_dir do
      "asc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end)
      "desc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end, &>=/2)
      _ -> models
    end
  end

  defp to_view_model(model) do
    %{
      "org_title" => model.dataset.business.orgTitle,
      "data_title" => model.dataset.business.dataTitle,
      "ingested_time" => Map.get(model, :ingested_time)
    }
  end
end
