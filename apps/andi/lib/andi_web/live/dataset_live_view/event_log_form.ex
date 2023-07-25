defmodule AndiWeb.EditLiveView.EventLogForm do
  @moduledoc """
  LiveComponent for viewing EventLog
  """
  use Phoenix.LiveView
  import Phoenix.HTML.Form

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

    event_log = Andi.InputSchemas.EventLogs.get_all_for_dataset_id(dataset.id)
      |> IO.inspect(label: "RYAN - Event Log")
    IO
    {:ok,
     assign(socket,
       visibility: "collapsed",
       validation_status: "collapsed",
       dataset: dataset,
       dataset_id: dataset.id,
       order: order,
       event_log: event_log
       )
    }
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

      <div class="component-edit-section--<%= @visibility %>">
        <div class="event_log_table">
          <%= for event <- @event_log do %>
            <div class="event_element"> Foo </div>
          <% end %>
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

end
