defmodule AndiWeb.EditLiveView.EventLogForm do
  @moduledoc """
  LiveComponent for viewing EventLog
  """
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  import AndiWeb.Helpers.SortingHelpers

  alias AndiWeb.ErrorHelpers
  alias AndiWeb.DataDictionary.Tree
  alias AndiWeb.InputSchemas.DataDictionaryFormSchema
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.DataDictionaryFields
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.InputConverter
  alias Ecto.Changeset

  def mount(_, %{"dataset" => dataset, "order" => order}, socket) do
    AndiWeb.Endpoint.subscribe("toggle-visibility")

    event_log =
      Andi.InputSchemas.EventLogs.get_all_for_dataset_id(dataset.id)
      |> convert_to_string_keys
      |> sort_list_by_field(:timestamp, "asc")

    {:ok,
     assign(socket,
       visibility: "collapsed",
       validation_status: "collapsed",
       dataset: dataset,
       dataset_id: dataset.id,
       order: order,
       event_log_order: %{"timestamp" => "asc"},
       event_log: event_log
     )}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
    <div id="event_log" class="form-component form-end">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="event_log_form">
        <div class="section-number">
          <div class="component-number component-number--<%= @validation_status %>"><%= @order %></div>
          <div class="component-number-status--<%= @validation_status %>"></div>
        </div>
        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %> ">Event Log</h2>
          <button aria-label="Event Log <%= action %>" type="button" class="btn btn--right btn--transparent component-title-button">
            <div class="component-title-action">
              <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
              <div class="component-title-icon--<%= @visibility %>"></div>
            </div>
          </button>
        </div>
      </div>
      <div class="form-section">
        <div class="component-edit-section--<%= @visibility %>">
          <div class="event_log_table">
            <table class="datasets-table" title="Event Log">
              <thead>
                <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@event_log_order, "timestamp", "unsorted") %>" phx-click="order-by" phx-value-field="timestamp">Timestamp</th>
                <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@event_log_order, "source", "unsorted") %>" phx-click="order-by" phx-value-field="source">Source</th>
                <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@event_log_order, "title", "unsorted") %>" phx-click="order-by" phx-value-field="title">Title</th>
                <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@event_log_order, "dataset_id", "unsorted") %>" phx-click="order-by" phx-value-field="dataset_id">Dataset ID</th>
                <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@event_log_order, "ingestion_id", "unsorted") %>" phx-click="order-by" phx-value-field="ingestion_id">Ingestion ID</th>
                <th class="datasets-table__th datasets-table__cell datasets-table__th--sortable datasets-table__th--<%= Map.get(@event_log_order, "description", "unsorted") %>" phx-click="order-by" phx-value-field="description">Description</th>
              </thead>

              <%= for event <- @event_log do %>
                <tr class="datasets-table__tr">
                  <td class="datasets-table__cell datasets-table__cell"><%= event["timestamp"] %></td>
                  <td class="datasets-table__cell datasets-table__cell--break"><%= event["source"] %></td>
                  <td class="datasets-table__cell datasets-table__cell--break datasets-table__data-title-cell"><%= event["title"] %></td>
                  <td class="datasets-table__cell datasets-table__cell"><%= event["dataset_id"] %></td>
                  <td class="datasets-table__cell datasets-table__cell--break datasets-table__data-title-cell"><%= event["ingestion_id"] %></td>
                  <td class="datasets-table__cell datasets-table__cell--break"><%= event["description"] %></td>
                </tr>
              <% end %>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("toggle-component-visibility", %{"component-expand" => next_component}, socket) do
    new_validation_status = "valid"

    AndiWeb.Endpoint.broadcast_from(self(), "toggle-visibility", "toggle-component-visibility", %{
      expand: next_component,
      dataset_id: socket.assigns.dataset_id
    })

    {:noreply, assign(socket, visibility: "collapsed", validation_status: new_validation_status)}
  end

  def handle_event("toggle-component-visibility", _, socket) do
    current_visibility = Map.get(socket.assigns, :visibility)

    new_visibility =
      case current_visibility do
        "expanded" -> "collapsed"
        "collapsed" -> "expanded"
      end

    {:noreply, assign(socket, visibility: new_visibility)}
  end

  def handle_info(
        %{
          topic: "toggle-visibility",
          payload: %{expand: "event_log", dataset_id: dataset_id}
        },
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    {:noreply, assign(socket, visibility: "expanded")}
  end

  def handle_info(%{topic: "toggle-visibility"}, socket) do
    {:noreply, socket}
  end

  def handle_event("order-by", %{"field" => field}, socket) do
    order_dir =
      case Map.get(socket.assigns.event_log_order, field, "asc") do
        "asc" -> "desc"
        _ -> "asc"
      end

    new_event_log = socket.assigns.event_log |> sort_list_by_field(field, order_dir)

    {:noreply, assign(socket, event_log_order: %{field => order_dir}, event_log: new_event_log)}
  end

  def get_visibility_value(visibility) do
    case visibility do
      "collapsed" -> "EDIT"
      "expanded" -> "MINIMIZE"
    end
  end

  defp convert_to_string_keys(event_logs) do
    Enum.map(event_logs, &to_string_keys/1)
  end

  defp to_string_keys(event_log) do
    %{
      "dataset_id" => event_log.dataset_id,
      "description" => event_log.description,
      "ingestion_id" => event_log.ingestion_id,
      "source" => event_log.source,
      "timestamp" => event_log.timestamp,
      "title" => event_log.title
    }
  end
end
