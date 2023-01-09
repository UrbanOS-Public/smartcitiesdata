defmodule AndiWeb.IngestionLiveView.Transformations.TransformationsStep do
  @moduledoc """
  LiveComponent for organizing individual transformation configurations
  """
  use Phoenix.LiveView

  require Logger

  alias Andi.InputSchemas.Ingestions.Transformations
  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.IngestionLiveView.FormUpdate
  alias AndiWeb.Helpers.TransformationHelpers

  def mount(_params, %{"ingestion" => ingestion, "order" => order}, socket) do
    AndiWeb.Endpoint.subscribe("form-save")
    AndiWeb.Endpoint.subscribe("transformation")
    AndiWeb.Endpoint.subscribe("toggle-visibility")

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
          <div class="component-number component-number--<%= @validation_status %>"><%= @order %></div>
          <div class="component-number-status--<%= @validation_status %>"></div>
        </div>
        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %> ">Transformations</h2>
          <button type="button" class="btn btn--right btn--transparent component-title-button">
            <div class="component-title-action">
              <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
              <div class="component-title-icon--<%= @visibility %>"></div>
            </div>
          </button>
        </div>
      </div>

      <div id="transformations-form-section" class="form-section">
        <div class="component-edit-section--<%= @visibility %> transformations--<%= @visibility %>">

          <div id="transformation-forms">
            <%= for changeset <- @transformation_changesets do %>
              <%= live_render(@socket, AndiWeb.IngestionLiveView.Transformations.TransformationForm, id: "transform-#{changeset.changes.id}", session: %{"transformation_changeset" => changeset}) %>
            <% end %>
          </div>

          <button id="add-transformation" class="btn btn--primary-outline btn--save btn--large" type="button" phx-click="add-transformation">+ Add New Transformation</button>

        </div>
      </div>
    </div>
    """
  end

  def handle_info(
        %{topic: "form-save", event: "save-all", payload: %{ingestion_id: ingestion_id}},
        %{assigns: %{transformations: transformations}} = socket
      ) do
    update_kept_transformations(transformations)
    delete_discarded_transformations(transformations, ingestion_id)
    {:noreply, socket}
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{topic: "transformation", event: "changed", payload: %{transformation_changeset: new_changeset}},
        %{assigns: %{transformation_changesets: transformation_changesets}} = socket
      ) do
    updated_changesets =
      Enum.map(transformation_changesets, fn changeset ->
        if changeset.changes.id == new_changeset.changes.id do
          new_changeset
        else
          changeset
        end
      end)

    {:noreply, assign(socket, transformation_changesets: updated_changesets)}
  end

  def handle_event("move-transformation", %{"id" => transformation_id, "move-index" => move_index_string}, socket) do
    move_index = String.to_integer(move_index_string)
    transformation_index = Enum.find_index(socket.assigns.transformations, fn transformation -> transformation.id == transformation_id end)
    target_index = transformation_index + move_index

    case target_index >= 0 && target_index < Enum.count(socket.assigns.transformations) do
      true -> move_transformation(socket, transformation_index, target_index)
      false -> {:noreply, socket}
    end
  end

  def handle_event("delete-transformation", %{"id" => transformation_id}, socket) do
    filtered_changesets =
      socket.assigns.transformation_changesets
      |> Enum.filter(fn changeset -> changeset.changes.id != transformation_id end)

    filtered_transformations =
      socket.assigns.transformations
      |> Enum.filter(fn transformation -> transformation.id != transformation_id end)

    FormUpdate.send_value(socket.parent_pid, :form_update)
    {:noreply, assign(socket, transformation_changesets: filtered_changesets, transformations: filtered_transformations)}
  end

  def handle_event("add-transformation", _, socket) do
    new_transformation = Transformations.create()

    FormUpdate.send_value(socket.parent_pid, :form_update)

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

    new_validation_status = update_validation_status(socket.assigns.transformation_changesets, new_visibility)
    {:noreply, assign(socket, visibility: new_visibility, validation_status: new_validation_status)}
  end

  defp move_transformation(socket, transformation_index, target_index) do
    updated_transformations =
      socket.assigns.transformations
      |> TransformationHelpers.move_element(transformation_index, target_index)
      |> Enum.with_index()
      |> Enum.map(fn {transformation, index} ->
        %{transformation | sequence: index}
      end)

    transformation_changesets =
      Enum.map(updated_transformations, fn transformation ->
        Transformation.convert_andi_transformation_to_changeset(transformation)
      end)

    FormUpdate.send_value(socket.parent_pid, :form_update)

    {:noreply, assign(socket, transformations: updated_transformations, transformation_changesets: transformation_changesets)}
  end

  defp update_kept_transformations(transformations) do
    Enum.each(transformations, fn transformation ->
      Transformations.update(transformation)
    end)
  end

  defp update_validation_status(transformation_changesets, visibility) do
    updated_changesets =
      Enum.map(transformation_changesets, fn changeset ->
        Transformation.changeset(changeset.changes)
      end)

    all_changesets_valid = Enum.map(updated_changesets, fn changeset -> changeset.valid? end) |> Enum.all?()

    cond do
      visibility == "expanded" -> "expanded"
      all_changesets_valid -> "valid"
      true -> "invalid"
    end
  end

  defp delete_discarded_transformations(transformations, ingestion_id) do
    kept_transformation_ids = Enum.map(transformations, fn transformation -> transformation.id end)

    Transformations.all_for_ingestion(ingestion_id)
    |> Enum.map(fn transformation -> transformation.id end)
    |> Enum.filter(fn id -> id not in kept_transformation_ids end)
    |> Enum.each(fn id -> Transformations.delete(id) end)
  end
end
