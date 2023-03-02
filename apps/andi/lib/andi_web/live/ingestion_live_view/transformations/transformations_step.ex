defmodule AndiWeb.IngestionLiveView.Transformations.TransformationsStep do
  @moduledoc """
  LiveComponent for organizing individual transformation configurations
  """
  use Phoenix.LiveComponent

  require Logger

  # alias Andi.InputSchemas.Ingestions.Transformations
  # alias Andi.InputSchemas.Ingestions.Transformation
  # alias AndiWeb.IngestionLiveView.FormUpdate
  # alias AndiWeb.Helpers.TransformationHelpers

  def component_id() do
    :transformations_form_editor
  end

  def component_step(), do: "Transformations"

  def mount(socket) do

    {:ok,
     assign(socket, visible?: false)}
  end

  def render(assigns) do
    visible = if assigns.visible?, do: "expanded", else: "collapsed"

    ~L"""
    <div id="transformations-step-form" class="form-component">
      <% live_component(
        @socket,
        AndiWeb.FormCollapsibleHeader,
        order: @order,
        visible: @visible?,
        validation_status: "invalid",
        step: component_step(),
        id: AndiWeb.FormCollapsibleHeader.component_id(component_step()),
        visibility_change_callback: &change_visibility/1)
      %>

      <div id="extract-step-form-section" class="form-section">
        <div class="component-edit-section--<%= visible %>">
          <div id="transformation-forms">
            <%= for changeset <- @transformation_changesets do %>
              <p><%= %></p>
            <% end %>
          </div>

          <button id="add-transformation" class="btn btn--primary-outline btn--save btn--large" type="button" phx-click="add-transformation">+ Add New Transformation</button>
        </div>
      </div>
    </div>
    """
    # <%= live_render(@socket, AndiWeb.IngestionLiveView.Transformations.TransformationForm, id: "transform-#{changeset.changes.id}", session: %{"transformation_changeset" => changeset}) %>
  end

  def change_visibility(updated_visibility) do
    send_update(__MODULE__,
      id: component_id(),
      visible?: updated_visibility
    )
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  # def handle_info(
  #       %{topic: "form-save", event: "save-all", payload: %{ingestion_id: ingestion_id}},
  #       %{assigns: %{transformations: transformations}} = socket
  #     ) do
  #   update_kept_transformations(transformations)
  #   delete_discarded_transformations(transformations, ingestion_id)
  #   {:noreply, socket}
  # end

  # def handle_info(%{topic: "form-save"}, socket) do
  #   {:noreply, socket}
  # end

  # def handle_info(
  #       %{topic: "transformation", event: "changed", payload: %{transformation_changeset: new_changeset}},
  #       %{assigns: %{transformation_changesets: transformation_changesets}} = socket
  #     ) do
  #   updated_changesets =
  #     Enum.map(transformation_changesets, fn changeset ->
  #       if changeset.changes.id == new_changeset.changes.id do
  #         new_changeset
  #       else
  #         changeset
  #       end
  #     end)

  #   {:noreply, assign(socket, transformation_changesets: updated_changesets)}
  # end

  # def handle_event("move-transformation", %{"id" => transformation_id, "move-index" => move_index_string}, socket) do
  #   move_index = String.to_integer(move_index_string)
  #   transformation_index = Enum.find_index(socket.assigns.transformations, fn transformation -> transformation.id == transformation_id end)
  #   target_index = transformation_index + move_index

  #   case target_index >= 0 && target_index < Enum.count(socket.assigns.transformations) do
  #     true -> move_transformation(socket, transformation_index, target_index)
  #     false -> {:noreply, socket}
  #   end
  # end

  # def handle_event("delete-transformation", %{"id" => transformation_id}, socket) do
  #   filtered_changesets =
  #     socket.assigns.transformation_changesets
  #     |> Enum.filter(fn changeset -> changeset.changes.id != transformation_id end)

  #   filtered_transformations =
  #     socket.assigns.transformations
  #     |> Enum.filter(fn transformation -> transformation.id != transformation_id end)

  #   FormUpdate.send_value(socket.parent_pid, :form_update)
  #   {:noreply, assign(socket, transformation_changesets: filtered_changesets, transformations: filtered_transformations)}
  # end

  # def handle_event("add-transformation", _, socket) do
  #   new_transformation = Transformations.create()

  #   FormUpdate.send_value(socket.parent_pid, :form_update)

  #   {:noreply,
  #    assign(socket,
  #      transformation_changesets: socket.assigns.transformation_changesets ++ [new_transformation],
  #      transformations: socket.assigns.transformations ++ [Transformations.get(new_transformation.changes.id)]
  #    )}
  # end

  # def handle_event("toggle-component-visibility", _, socket) do
  #   current_visibility = Map.get(socket.assigns, :visibility)

  #   new_visibility =
  #     case current_visibility do
  #       "expanded" -> "collapsed"
  #       "collapsed" -> "expanded"
  #     end

  #   new_validation_status = update_validation_status(socket.assigns.transformation_changesets, new_visibility)
  #   {:noreply, assign(socket, visibility: new_visibility, validation_status: new_validation_status)}
  # end

  # defp move_transformation(socket, transformation_index, target_index) do
  #   updated_transformations =
  #     socket.assigns.transformations
  #     |> TransformationHelpers.move_element(transformation_index, target_index)
  #     |> Enum.with_index()
  #     |> Enum.map(fn {transformation, index} ->
  #       %{transformation | sequence: index}
  #     end)

  #   transformation_changesets =
  #     Enum.map(updated_transformations, fn transformation ->
  #       Transformation.convert_andi_transformation_to_changeset(transformation)
  #     end)

  #   FormUpdate.send_value(socket.parent_pid, :form_update)

  #   {:noreply, assign(socket, transformations: updated_transformations, transformation_changesets: transformation_changesets)}
  # end

  # defp update_kept_transformations(transformations) do
  #   Enum.each(transformations, fn transformation ->
  #     Transformations.update(transformation)
  #   end)
  # end

  # defp update_validation_status(transformation_changesets, visibility) do
  #   updated_changesets =
  #     Enum.map(transformation_changesets, fn changeset ->
  #       Transformation.changeset(changeset.changes)
  #     end)

  #   all_changesets_valid = Enum.map(updated_changesets, fn changeset -> changeset.valid? end) |> Enum.all?()

  #   cond do
  #     visibility == "expanded" -> "expanded"
  #     all_changesets_valid -> "valid"
  #     true -> "invalid"
  #   end
  # end

  # defp delete_discarded_transformations(transformations, ingestion_id) do
  #   kept_transformation_ids = Enum.map(transformations, fn transformation -> transformation.id end)

  #   Transformations.all_for_ingestion(ingestion_id)
  #   |> Enum.map(fn transformation -> transformation.id end)
  #   |> Enum.filter(fn id -> id not in kept_transformation_ids end)
  #   |> Enum.each(fn id -> Transformations.delete(id) end)
  # end
end
