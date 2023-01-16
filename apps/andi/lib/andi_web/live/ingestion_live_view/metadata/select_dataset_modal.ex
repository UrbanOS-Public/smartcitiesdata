defmodule AndiWeb.IngestionLiveView.SelectDatasetModal do
  use Phoenix.LiveComponent

  import Ecto.Query, only: [from: 2]

  alias Andi.InputSchemas.Datasets.Dataset

  def mount(socket) do
    {:ok,
     assign(socket,
       search_results: [],
       selected_dataset: nil,
       old_selected_dataset: nil,
       search_text: ""
     )}
  end

  def render(assigns) do
    ~L"""
    <div class="manage-datasets-modal manage-datasets-modal--<%= @visibility %>">
      <div class="modal-form-container search-modal" x-trap="<%= @visibility === "visible" %>">
        <div class="search-index__header">
          <h2 class="search-index__title">Dataset Search</h2>
          <button id="close-select-dataset-modal" type="button" class="btn btn--transparent material-icons search-index__exit" phx-click="cancel-dataset-search" phx-target="<%= @myself %>" >close</span>
        </div>

        <hr class="search-modal-divider">

        <p class="search-modal-helper-text">Search by dataset title, keywords, or organization.</p>

        <div class="search-modal__search_bar">
          <p class="search-modal-section-header-text">Search</p>
          <form phx-change="datasets-search" phx-submit="datasets-search" phx-target="<%= @myself %>">
            <div class="search-modal__search_bar-input-container">
              <label for="search-modal__search_bar-input-select-dataset">
                <i class="material-icons search-modal__search_bar-icon">search</i>
              </label>
              <input
                name="search-value"
                phx-debounce="250"
                id="search-modal__search_bar-input-select-dataset"
                class="search-modal__search_bar-input"
                type="text"
                value="<%= @search_text %>"
                placeholder="Search dataset"
              >
            </div>
          </form>
        </div>
        <div id="<%= @id %>">

        <div class="dataset-modal-search-results">
          <p class="search-modal-section-header-text">Results</p>
          <div class="search-modal-results-table">
            <table class="search-table" title="Dataset Search Results">
              <thead>
                <th class="search-table__th search-table__cell wide-column" id="dataset">Dataset</th>
                <th class="search-table__th search-table__cell wide-column">Organization</th>
                <th class="search-table__th search-table__cell wide-column">Keywords</th>
                <th class="search-table__th search-table__cell thin-column">Action</th>
              </thead>

              <%= if @search_results == [] do %>
                <tr><td class="search-table__cell" colspan="100%" headers="dataset">No Matching Datasets</td></tr>
              <% else %>
                <%= for dataset <- @search_results do %>
                <tr class="search-table__tr">
                    <td class="search-table__cell search-table__cell--break search-table__data-title-cell wide-column"><%= dataset.business.dataTitle %></td>
                    <td class="search-table__cell search-table__cell--break wide-column"><%= dataset.business.orgTitle %></td>
                    <td class="search-table__cell search-table__cell--break wide-column"><%= Enum.join(dataset.business.keywords, ", ") %></td>
                    <td class="search-table__cell search-table__cell--break thin-column">
                      <a class="modal-action-text" href="javascript:void(0)" phx-click="select-dataset-search" phx-target="<%= @myself %>" phx-value-id=<%= dataset.id %>><%=selected_value(dataset.id, @selected_dataset)%></a>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </table>
          </div>
        </div>
      </div>

    <div class="dataset-search-selected-datasets">
        <p class="search-modal-section-header-text">Selected Dataset</p>
        <div class="selected-results-from-search">
          <%= if(selected_dataset(@search_results, @selected_dataset) == nil) do %>
            <div></div>
          <% else %>
            <div class="selected-result-from-search">
              <span class="selected-result-text"><%= get_dataset_name(@selected_dataset) %></span>
              <button type="button" class="btn btn--transparent material-icons remove-selected-result" phx-click="remove-selected-dataset" phx-target="<%= @myself %>" phx-value-id=<%= @selected_dataset %>>close</button>
            </div>
          <% end %>
        </div>
    </div>

    <hr class="search-modal-divider">

    <div class="btn-group__standard">
          <button id="save-dataset-search-button" name="save-dataset-search-button" class="btn btn--primary-outline btn--large save-search" type="button" phx-click="save-dataset-search" phx-target="<%= @myself %>" >  Save</button>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("save-dataset-search", _, socket) do
    socket.assigns.close_modal_callback.()
    send(self(), {:update_dataset, socket.assigns.selected_dataset})

    {:noreply, socket}
  end

  def handle_event("cancel-dataset-search", _, socket) do
    socket.assigns.close_modal_callback.()

    {:noreply, socket}
  end

  def handle_event("datasets-search", %{"search-value" => search_value}, socket) do
    search_results = query_on_dataset_search_change(search_value, socket)

    {:noreply,
     assign(socket,
       search_text: search_value,
       search_results: search_results,
       selected_dataset: socket.assigns.selected_dataset
     )}
  end

  def handle_event("remove-selected-dataset", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_dataset: nil, old_selected_dataset: id)}
  end

  def handle_event("select-dataset-search", %{"id" => id}, socket) do
    if(socket.assigns.selected_dataset == id) do
      {:noreply, assign(socket, selected_dataset: nil, old_selected_dataset: id)}
    else
      {:noreply, assign(socket, selected_dataset: id, old_selected_dataset: socket.assigns.selected_dataset)}
    end
  end

  def handle_event(event, payload, socket) do
    IO.inspect("Event: #{event}, payload: #{payload}, socket: #{socket}", label: 'Unhandled Event in module #{__MODULE__}}')

    {:noreply, socket}
  end

  def handle_event(event, socket) do
    IO.inspect("Event: #{event}, socket: #{socket}", label: 'Unhandled Event in module #{__MODULE__}}')

    {:noreply, socket}
  end

  defp query_on_dataset_search_change(search_value, %{assigns: %{search_text: search_value, search_results: search_results}}) do
    search_results
  end

  defp query_on_dataset_search_change(search_value, _) do
    refresh_dataset_search_results(search_value)
  end

  defp refresh_dataset_search_results(search_value) do
    like_search_string = "%#{search_value}%"

    query =
      from(dataset in Dataset,
        join: technical in assoc(dataset, :technical),
        join: business in assoc(dataset, :business),
        preload: [business: business, technical: technical],
        where: not is_nil(technical.id),
        where: not is_nil(business.id),
        where: ilike(business.dataTitle, type(^like_search_string, :string)),
        or_where: ilike(business.orgTitle, type(^like_search_string, :string)),
        or_where: ^search_value in business.keywords,
        select: dataset
      )

    query
    |> Andi.Repo.all()
  end

  defp selected_dataset(datasets, selected_dataset) do
    if(selected_dataset == nil) do
      nil
    else
      case Enum.find(datasets, fn dataset -> dataset.id == selected_dataset end) do
        nil -> Andi.InputSchemas.Datasets.get(selected_dataset)
        result -> result
      end
    end
  end

  defp selected_value(dataset_id, selected_dataset) do
    case dataset_id == selected_dataset do
      true -> "Remove"
      false -> "Select"
    end
  end

  defp get_dataset_name(id) do
    dataset = Andi.InputSchemas.Datasets.get(id)
    dataset.business.dataTitle
  end
end
