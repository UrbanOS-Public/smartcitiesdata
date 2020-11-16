defmodule AndiWeb.DatasetLiveView do
  use Phoenix.LiveView
  use AndiWeb.HeaderLiveView

  import Ecto.Query, only: [from: 2]

  alias AndiWeb.Router.Helpers, as: Routes
  alias AndiWeb.DatasetLiveView.Table
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset

  import AndiWeb.Helpers.SortingHelpers

  @default_filters [
    include_remotes: false,
    only_submitted: false
  ]

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="datasets-view">
      <div class="datasets-index">
        <div class="datasets-index__header">
          <h1 class="datasets-index__title"><%= title_text(@is_curator) %></h1>
          <button type="button" class="btn btn--add-dataset btn--action" phx-click="add-dataset"><%= action_text(@is_curator) %></button>
        </div>

        <div class="input-container">
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

          <label class="checkbox">
            <input type="checkbox" phx-click="toggle_remotes" <%= if !@include_remotes, do: "checked" %>/>
            <span>Exclude Remote Datasets</span>
          </label>

          <label class="checkbox">
            <input type="checkbox" phx-click="toggle_submitted" <%= if @only_submitted, do: "checked" %>/>
            <span>Show Submitted Datasets Only</span>
          </label>
        </div>

        <%= live_component(@socket, Table, id: :datasets_table, datasets: @view_models, order: @order) %>
      </div>
    </div>
    """
  end

  def mount(_params, %{"user_id" => user_id, "is_curator" => is_curator} = _session, socket) do
    {:ok,
     assign(socket,
       datasets: nil,
       user_id: user_id,
       search_text: nil,
       include_remotes: default_for_filter(:include_remotes),
       only_submitted: default_for_filter(:only_submitted),
       is_curator: is_curator,
       order: {"data_title", "asc"},
       params: %{}
     )}
  end

  def handle_params(params, _uri, socket) do
    order_by = Map.get(params, "order-by", "data_title")
    order_dir = Map.get(params, "order-dir", "asc")
    search_text = Map.get(params, "search", "")
    include_remotes = include_remotes?(params)
    only_submitted = only_submitted?(params)

    datasets = query_on_search_change(search_text, socket)

    view_models = datasets
    |> filter_remotes(include_remotes)
    |> filter_submitted(only_submitted)
    |> convert_to_view_models()
    |> sort_list_by_field(order_by, order_dir)

    {:noreply,
     assign(socket,
       search_text: search_text,
       view_models: view_models,
       datasets: datasets,
       order: %{order_by => order_dir},
       params: params,
       include_remotes: include_remotes,
       only_submitted: only_submitted
     )}
  end

  def handle_event("add-dataset", _, socket) do
    owner = Andi.Repo.get(Andi.Schemas.User, socket.assigns.user_id)
    new_dataset = Datasets.create(owner)

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

  def handle_event("toggle_remotes", _, socket) do
    current_include_remotes = include_remotes?(socket.assigns.params)

    search_params = Map.merge(socket.assigns.params, %{"include-remotes" => !current_include_remotes})

    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, search_params))}
  end

  def handle_event("toggle_submitted", _, socket) do
    current_only_submitted = only_submitted?(socket.assigns.params)

    search_params = Map.merge(socket.assigns.params, %{"only-submitted" => !current_only_submitted})

    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, search_params))}
  end

  defp query_on_search_change(search_value, %{assigns: %{search_text: search_value, datasets: datasets}}) do
    datasets
  end
  defp query_on_search_change(search_value, socket) do
    owner_id = socket.assigns.is_curator || socket.assigns.user_id

    refresh_datasets(search_value, owner_id)
  end

  defp refresh_datasets(search_value, owner_id) do
    search_string = "%#{search_value}%"

    query =
      from(dataset in Dataset,
        join: technical in assoc(dataset, :technical),
        join: business in assoc(dataset, :business),
        preload: [business: business, technical: technical],
        where: not is_nil(technical.id),
        where: not is_nil(business.id),
        where: ilike(business.dataTitle, type(^search_string, :string)),
        or_where: ilike(business.orgTitle, type(^search_string, :string)),
        select: dataset
      )

    query
    |> filter_by_owner(owner_id)
    |> Andi.Repo.all()
  end

  def filter_by_owner(query, owner_id) when owner_id in [true, nil], do: query
  def filter_by_owner(query, owner_id), do: Ecto.Query.where(query, owner_id: ^owner_id)

  defp filter_remotes(datasets, false) do
    Enum.reject(datasets, fn dataset -> dataset.technical.sourceType == "remote" end)
  end

  defp filter_remotes(datasets, true), do: datasets
  defp filter_submitted(datasets, true) do
    Enum.filter(datasets, fn dataset -> dataset.submission_status == :submitted end)
  end
  defp filter_submitted(datasets, false), do: datasets

  defp convert_to_view_models(datasets) do
    Enum.map(datasets, &to_view_model/1)
  end

  defp to_view_model(dataset) do
    %{
      "id" => dataset.id,
      "org_title" => dataset.business.orgTitle,
      "data_title" => dataset.business.dataTitle,
      "remote" => dataset.technical.sourceType == "remote",
      "status" => status(dataset),
      "status_sort" => status_sort(dataset)
    }
  end

  defp status(%{ingestedTime: nil, submission_status: status}), do: String.capitalize(Atom.to_string(status))
  defp status(dataset), do: ingest_status(dataset)

  defp status_sort(%{ingestedTime: nil, submission_status: status}), do: status
  defp status_sort(%{ingestedTime: it}), do: it

  defp ingest_status(dataset) do
    case has_recent_dlq_message?(dataset.dlq_message) do
      true -> "Error"
      _ -> "Success"
    end
  end

  defp has_recent_dlq_message?(nil), do: false

  defp has_recent_dlq_message?(message) do
    message_timestamp = message["timestamp"]
    message_received_within?(message_timestamp, 7, :days)
  end

  defp message_received_within?(message_timestamp, length_of_time, interval) do
    {:ok, message_datetime, _} = DateTime.from_iso8601(message_timestamp)
    message_age = Timex.diff(DateTime.utc_now(), message_datetime, interval)

    message_age <= length_of_time
  end

  def string_to_bool("true"), do: true
  def string_to_bool("false"), do: false

  defp title_text(true = _is_curator), do: "All Datasets"
  defp title_text(false = _is_curator), do: "My Datasets"

  defp action_text(true = _is_curator), do: "ADD DATASET"
  defp action_text(false = _is_curator), do: "SUBMIT NEW DATASET"

  defp default_for_filter(name) do
    Keyword.get(@default_filters, name)
  end

  defp default_for_filter_as_string(name) do
    default_for_filter(name)
    |> Atom.to_string()
  end

  defp include_remotes?(params) do
    params
    |> Map.get("include-remotes", default_for_filter_as_string(:include_remotes))
    |> string_to_bool()
  end

  defp only_submitted?(params) do
    params
    |> Map.get("only-submitted", default_for_filter_as_string(:only_submitted))
    |> string_to_bool()
  end
end
