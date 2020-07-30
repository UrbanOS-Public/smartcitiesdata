defmodule AndiWeb.DatasetLiveView do
  use Phoenix.LiveView

  alias AndiWeb.Router.Helpers, as: Routes
  alias AndiWeb.DatasetLiveView.Table
  alias Andi.InputSchemas.Datasets

  @ingested_time_topic "ingested_time_topic"

  def render(assigns) do
    ~L"""
    <div class="datasets-view">
      <div class="datasets-index">
        <div class="datasets-index__header">
          <h1 class="datasets-index__title">All Datasets</h1>
          <button type="button" class="btn btn--add-dataset btn--action" phx-click="add-dataset">ADD DATASET</button>
        </div>

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
    </div>
    """
  end

  def mount(_params, _session, socket) do
    AndiWeb.Endpoint.subscribe(@ingested_time_topic)
    {:ok, assign(socket, datasets: nil, search_text: nil, order: {"data_title", "asc"}, params: %{})}
  end

  def handle_info(%{topic: @ingested_time_topic}, socket) do
    %{search_text: search_text, order: order} = socket.assigns
    {order_by, order_dir} = coerce_order_into_tuple(order)

    updated_datasets =
      refresh_datasets(search_text)
      |> sort_by_dir(order_by, order_dir)

    updated_state = assign(socket, :datasets, updated_datasets)

    {:noreply, updated_state}
  end

  defp coerce_order_into_tuple(order) when is_tuple(order), do: order

  defp coerce_order_into_tuple(order) when is_map(order) do
    [{order_by, order_dir}] = Map.to_list(order)
    {order_by, order_dir}
  end

  def handle_params(params, _uri, socket) do
    order_by = Map.get(params, "order-by", "data_title")
    order_dir = Map.get(params, "order-dir", "asc")
    search_text = Map.get(params, "search", "")

    view_models =
      filter_on_search_change(search_text, socket)
      |> sort_by_dir(order_by, order_dir)

    {:noreply, assign(socket, search_text: search_text, datasets: view_models, order: %{order_by => order_dir}, params: params)}
  end

  def handle_event("add-dataset", _, socket) do
    new_dataset = Datasets.create()

    {:noreply, push_redirect(socket, to: "/datasets/#{new_dataset.id}")}
  end

  def handle_event("search", %{"search-value" => value}, socket) do
    search_params = Map.merge(socket.assigns.params, %{"search" => value})
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, search_params))}
  end

  def handle_event("order-by", %{"field" => field}, socket) do
    order_dir =
      case socket.assigns.order do
        %{^field => "asc"} -> "desc"
        _ -> "asc"
      end

    params = Map.merge(socket.assigns.params, %{"order-by" => field, "order-dir" => order_dir})
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, params))}
  end

  defp filter_on_search_change(search_value, socket) do
    case search_value == socket.assigns.search_text do
      false -> refresh_datasets(search_value)
      _ -> socket.assigns.datasets
    end
  end

  defp refresh_datasets(search_value) do
    Datasets.get_all()
    |> reject_partial_datasets()
    |> filter_datasets(search_value)
    |> Enum.map(&to_view_model/1)
  end

  defp reject_partial_datasets(datasets) do
    Enum.reject(datasets, fn
      %{business: %{id: _bid}, technical: %{id: _tid}} -> false
      _ -> true
    end)
  end

  defp filter_datasets(datasets, ""), do: datasets

  defp filter_datasets(datasets, value) do
    Enum.filter(datasets, fn dataset ->
      search_contains?(dataset.business.orgTitle, value) ||
        search_contains?(dataset.business.dataTitle, value)
    end)
  end

  defp search_contains?(nil, _search_str), do: false

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

  defp to_view_model(dataset) do
    %{
      "id" => dataset.id,
      "org_title" => dataset.business.orgTitle,
      "data_title" => dataset.business.dataTitle,
      "ingested_time" => dataset.ingestedTime
    }
  end
end
