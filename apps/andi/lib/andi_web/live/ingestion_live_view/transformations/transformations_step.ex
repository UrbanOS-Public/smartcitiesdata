defmodule AndiWeb.IngestionLiveView.Transformations.TransformationsStep do
  @moduledoc """
  LiveComponent for organizing individual transformation configurations
  """
  use Phoenix.LiveComponent

  require Logger

  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.IngestionLiveView.Transformations.TransformationForm
  alias Ecto.Changeset

  def component_id() do
    :transformations_form_editor
  end

  def component_step(), do: "Transformations"

  def mount(socket) do
    {:ok, assign(socket, visible?: false)}
  end

  def render(assigns) do
    visible = if assigns.visible?, do: "expanded", else: "collapsed"
    validation_status = get_validation_status(assigns.transformation_changesets)

    ~L"""
    <div id="transformations-step-form" class="form-component">
      <%= live_component(
        @socket,
        AndiWeb.FormCollapsibleHeader,
        order: @order,
        visible?: @visible?,
        validation_status: validation_status,
        step: component_step(),
        id: AndiWeb.FormCollapsibleHeader.component_id(component_step()),
        visibility_change_callback: &change_visibility/1)
      %>

      <div id="extract-step-form-section" class="form-section">
        <div class="component-edit-section--<%= visible %>">
          <div id="transformation-forms">
            <%= for changeset <- sort_by_sequence(@transformation_changesets) do %>
              <% {_, changeset_id} = Changeset.fetch_field(changeset, :id) %>
              <%= live_component(@socket, TransformationForm, id: changeset_id, transformation_changeset: changeset) %>
            <% end %>
          </div>

          <button id="add-transformation" class="btn btn--primary-outline btn--save btn--large" type="button" phx-click="add-transformation" phx-target="<%= @myself %>" aria-label="Add New Transformation">+ Add New Transformation</button>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("add-transformation", _, socket) do
    ingestion_id = socket.assigns.ingestion_id
    sequence = length(socket.assigns.transformation_changesets)

    new_changes = %{type: "", name: "", parameters: %{}, ingestion_id: ingestion_id, sequence: sequence}

    new_changeset = Transformation.changeset(%Transformation{}, new_changes)

    new_transformation_changesets = [new_changeset | socket.assigns.transformation_changesets] |> sort_by_sequence()

    send(self(), {:update_all_transformations, new_transformation_changesets})
    {:noreply, socket}
  end

  def change_visibility(updated_visibility) do
    send_update(__MODULE__,
      id: component_id(),
      visible?: updated_visibility
    )
  end

  def update_transformation(changeset, step_id) do
    send_update(__MODULE__,
      id: component_id(),
      updated_transformation_changeset: changeset,
      step_id: step_id
    )
  end

  def move_transformation(transformation_id, move_index) do
    send_update(__MODULE__,
      id: component_id(),
      action: "move",
      transformation_id: transformation_id,
      move_index: move_index
    )
  end

  def delete_transformation(transformation_id) do
    send_update(__MODULE__,
      id: component_id(),
      action: "delete",
      transformation_id: transformation_id
    )
  end

  def update(%{updated_transformation_changeset: changeset, step_id: step_id}, socket) do
    changes = StructTools.to_map(Changeset.apply_changes(changeset))

    updated_transformation_changesets =
      Enum.map(socket.assigns.transformation_changesets, fn changeset ->
        changeset_id =
          case Changeset.fetch_field(changeset, :id) do
            {_, id} -> id
            :error -> nil
          end

        case changeset_id == step_id do
          true -> Transformation.changeset(changeset, changes)
          false -> changeset
        end
      end)

    send(self(), {:update_all_transformations, updated_transformation_changesets})
    {:ok, socket}
  end

  def update(%{action: "move", transformation_id: transformation_id, move_index: move_index}, socket) do
    changeset_to_update =
      Enum.find(socket.assigns.transformation_changesets, fn changeset ->
        changeset_id =
          case Changeset.fetch_field(changeset, :id) do
            {_, id} -> id
            :error -> nil
          end

        changeset_id == transformation_id
      end)

    changeset_sequence =
      case Changeset.fetch_field(changeset_to_update, :sequence) do
        {_, sequence} -> sequence
        :error -> 0
      end

    new_index = changeset_sequence + move_index

    if new_index >= 0 and new_index < length(socket.assigns.transformation_changesets) do
      sorted_changesets =
        socket.assigns.transformation_changesets
        |> sort_by_sequence()

      {transformation_to_move, remaining_list} = List.pop_at(sorted_changesets, changeset_sequence)

      updated_transformation_changesets =
        List.insert_at(remaining_list, new_index, transformation_to_move)
        |> Enum.with_index()
        |> Enum.map(fn {changeset, index} ->
          Changeset.put_change(changeset, :sequence, index)
        end)

      send(self(), {:update_all_transformations, updated_transformation_changesets})
    end

    {:ok, socket}
  end

  def update(%{action: "delete", transformation_id: transformation_id}, socket) do
    element_to_delete =
      Enum.find(socket.assigns.transformation_changesets, fn changeset ->
        changeset_id =
          case Changeset.fetch_field(changeset, :id) do
            {_, id} -> id
            :error -> nil
          end

        changeset_id == transformation_id
      end)

    new_transformation_changesets =
      List.delete(socket.assigns.transformation_changesets, element_to_delete)
      |> sort_by_sequence()
      |> Enum.with_index()
      |> Enum.map(fn {changeset, index} ->
        Changeset.put_change(changeset, :sequence, index)
      end)

    send(self(), {:update_all_transformations, new_transformation_changesets})
    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp sort_by_sequence(changeset_list) do
    Enum.sort_by(changeset_list, &Changeset.fetch_field!(&1, :sequence))
  end

  defp get_validation_status(transformation_changesets) do
    case Enum.all?(transformation_changesets, fn changeset ->
           changeset.valid?
         end) do
      true -> "valid"
      false -> "invalid"
    end
  end
end
