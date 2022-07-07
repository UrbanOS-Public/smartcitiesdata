defmodule AndiWeb.IngestionLiveView.Transformations.TransformationsStep do
  @moduledoc """
  LiveComponent for organizing individual transformation configurations
  """
  use Phoenix.LiveView
  require Logger

  alias Andi.InputSchemas.Ingestions.Transformations
  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.Helpers.TransformationHelpers

  def mount(_params, %{"ingestion" => ingestion, "order" => order}, socket) do
    AndiWeb.Endpoint.subscribe("form-save")
    AndiWeb.Endpoint.subscribe("move-transformation")

    transformation_changesets =
      Enum.map(ingestion.transformations, fn transformation ->
        Transformation.convert_andi_transformation_to_changeset(transformation)
      end)

    {:ok,
     assign(socket,
       visibility: "collapsed",
       validation_status: "collapsed",
       ingestion_id: ingestion.id,
       order: order,
       transformation_changesets: transformation_changesets,
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
            <%= for changeset <- @transformation_changesets do %>
              <%= live_render(@socket, AndiWeb.IngestionLiveView.Transformations.TransformationForm, id: "transform-#{changeset.changes.id}", session: %{"transformation_changeset" => changeset}) %>
            <% end %>
            </div>

          <button id="add-transformation" class="btn btn--save btn--large" type="button" phx-click="add-transformation">+ Add New Transformation</button>

        </div>
      </div>
    </div>
    """
  end

  def handle_info(
        %{topic: "form-save", event: "save-all", payload: %{ingestion_id: ingestion_id}},
        %{assigns: %{transformations: transformations}} = socket
      ) do

    # Enum.each(transformations, fn transformation ->
    #   Transformations.update(transformation)
    # end)
    # {:noreply, socket}
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{
          topic: "move-transformation",
          event: "move-transformation",
          payload: %{"id" => transformation_id, "move-index" => move_index_string}
        },
        socket
      ) do
    move_index = String.to_integer(move_index_string)
    transformation_index = Enum.find_index(socket.assigns.transformations, fn transformation -> transformation.id == transformation_id end)
    target_index = transformation_index + move_index

    case target_index >= 0 && target_index < Enum.count(socket.assigns.transformations) do
      true -> move_transformation(socket, transformation_index, target_index)
      false -> {:noreply, socket}
    end
  end

  def handle_event("add-transformation", _, socket) do
    new_transformation = Transformations.create()

    {:noreply,
     assign(socket,
       transformation_changesets: socket.assigns.transformation_changesets ++ [new_transformation],
       transformations: socket.assigns.transformations ++ [Transformations.get(new_transformation.changes.id)]
     )}
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

  defp move_transformation(socket, transformation_index, target_index) do
    updated_transformations =
      socket.assigns.transformations
      |> TransformationHelpers.move_element(transformation_index, target_index)
      |> Enum.with_index()
      |> Enum.map(fn {transformation, index} ->
        {:ok, updated_transformation} = Transformations.update(transformation, %{sequence: index})
        updated_transformation
      end)

    transformation_changesets =
      Enum.map(updated_transformations, fn transformation ->
        Transformation.convert_andi_transformation_to_changeset(transformation)
      end)

    {:noreply, assign(socket, transformations: updated_transformations, transformation_changesets: transformation_changesets)}
  end
end
