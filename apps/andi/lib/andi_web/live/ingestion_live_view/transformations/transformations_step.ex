defmodule AndiWeb.IngestionLiveView.Transformations.TransformationsStep do
  @moduledoc """
  LiveComponent for organizing individual transformation configurations
  """
  use Phoenix.LiveView
  require Logger

  alias Andi.InputSchemas.Ingestions.Transformations
  alias Andi.InputSchemas.Ingestions.Transformation

  def mount(_params, %{"ingestion" => ingestion, "order" => order}, socket) do
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       visibility: "collapsed",
       validation_status: "collapsed",
       ingestion_id: ingestion.id,
       order: order,
       transformations: ingestion.transformations
     )}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
    <div id="transformations-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="transformations_form">
        <div class="section-number">
          <h3 class="component-number component-number--<%= @validation_status %>"><%= @order %></h3>
          <div class="component-number-status--<%= @validation_status %>"></div>
        </div>
        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %> ">Transformations</h2>
          <div class="component-title-action">
            <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
            <div class="component-title-icon--<%= @visibility %>"></div>
          </div>
        </div>
      </div>

      <div id="transformations-form-section" class="form-section">
        <div class="component-edit-section--<%= @visibility %> transformations--<%= @visibility %>">

          <div id="transformation-forms">
            <%= for transformation <- @transformations do %>
              <%= live_render(@socket, AndiWeb.IngestionLiveView.Transformations.TransformationForm, id: transformation.changes.id, session: %{"transformation" => transformation}) %>
            <% end %>
            </div>

          <button id="add-transformation" class="btn btn--save btn--large" type="button" phx-click="add-transformation">+ Add New Transformation</button>

        </div>
      </div>
    </div>
    """
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  def handle_event("add-transformation", _, socket) do
    {:noreply,
     assign(socket, transformations: [Transformations.create() | socket.assigns.transformations])
     |> IO.inspect(label: "what we have on socket")}
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
end
