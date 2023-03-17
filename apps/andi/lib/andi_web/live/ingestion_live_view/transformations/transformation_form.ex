defmodule AndiWeb.IngestionLiveView.Transformations.TransformationForm do
  @moduledoc """
  LiveComponent for editing an individual transformation
  """
  use Phoenix.LiveComponent

  require Logger
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Helpers.MetadataFormHelpers
  alias AndiWeb.Views.DisplayNames
  alias Ecto.Changeset
  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.IngestionLiveView.Transformations.TransformationFieldBuilder
  alias Transformers.TransformationFields

  def mount(socket) do
    {:ok,
     assign(socket,
       visible?: false
     )}
  end

  def render(assigns) do
    visible = if assigns.visible?, do: "expanded", else: "collapsed"

    ~L"""
    <%= f = form_for @transformation_changeset, "#", [ as: :form_data, phx_change: :validate, phx_target: @myself, id: @id, class: "transformation-item"] %>
      <div class="transformation-header full-width" id="transformation_<%= @id %>__header" phx-click="toggle-component-visibility" phx-target="<%= @myself %>">
        <h3 class="transformation-header-name"> <%= transformation_name(f) %> </h3>
        <div class="transformation-actions">
          <button class="material-icons transformation-action delete-transformation-button delete-<%= @transformation_changeset.changes.id %>" type="button" phx-click="delete-transformation" phx-value-id="<%= @transformation_changeset.changes.id %>" phx-target="<%= @myself %>">delete_outline</button>
          <button class="material-icons transformation-action" type="button">edit</button>
          <% {_, transformation_changeset_id} = Changeset.fetch_field(@transformation_changeset, :id) %>
          <button class="material-icons transformation-action move-button move-up" type="button" phx-click="move-transformation" phx-value-id="<%= transformation_changeset_id %>" phx-value-move-index="-1" phx-target="<%= @myself %>">arrow_upward</button>
          <button class="material-icons transformation-action move-button move-down" type="button" phx-click="move-transformation" phx-value-id="<%= transformation_changeset_id %>" phx-value-move-index="1" phx-target="<%= @myself %>">arrow_downward</button>
        </div>
      </div>

      <div class="transformation-form transformation-edit-form--<%= visible %>">
        <div class="transformation-form__name">
          <%= label(f, :name, "Name", class: "label label--required", for: "transformation_#{@id}__name") %>
          <%= text_input(f, :name, [id: "transformation_#{@id}__name", class: "transformation-name input transformation-form-fields", required: true]) %>
          <%= ErrorHelpers.error_tag(f, :name, bind_to_input: false, id: "#{@id}_transformation_name_error") %>
        </div>
        <div class="transformation-form__type">
          <%= label(f, :type, DisplayNames.get(:transformationType), class: "label label--required", for: "transformation_#{@id}__type") %>
          <%= select(f, :type, get_transformation_types(), [id: "transformation_#{@id}__type", class: "select transformation-type", required: true]) %>
          <%= ErrorHelpers.error_tag(f.source, :type, bind_to_input: false, id: "#{@id}_transformation_type_error") %>
        </div>
        <div class="transformation-form__fields">
          <%= for field <- get_fields(input_value(f, :type)) do %>
            <%= TransformationFieldBuilder.build_input(field, assigns, f, "transformation_#{@id}__#{field.field_name}") %>
          <% end %>
        </div>
      </div>
    </form>
    """
  end

  defp get_transformation_types(), do: map_to_dropdown_options(MetadataFormHelpers.get_transformation_type_options())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} ->
      [key: description, value: actual_value]
    end)
  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => ["form_data", "type"]}, socket) do
    non_parameter_form_data =
      Enum.reduce(form_data, %{}, fn {key, value}, acc ->
        if key in ["name", "type"] do
          Map.put(acc, key, value)
        else
          acc
        end
      end)
      |> Map.put(:parameters, %{})

    transformation = Transformation.changeset(socket.assigns.transformation_changeset, non_parameter_form_data)

    AndiWeb.IngestionLiveView.Transformations.TransformationsStep.update_transformation(transformation, socket.assigns.id)

    {:noreply, socket}
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    transformation = Transformation.changeset(socket.assigns.transformation_changeset, form_data)

    AndiWeb.IngestionLiveView.Transformations.TransformationsStep.update_transformation(transformation, socket.assigns.id)

    {:noreply, socket}
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def handle_event("move-transformation", %{"id" => transformation_id, "move-index" => move_index_string}, socket) do
    move_index = String.to_integer(move_index_string)

    AndiWeb.IngestionLiveView.Transformations.TransformationsStep.move_transformation(transformation_id, move_index)

    {:noreply, socket}
  end

  def handle_event("delete-transformation", %{"id" => transformation_id}, socket) do
    AndiWeb.IngestionLiveView.Transformations.TransformationsStep.delete_transformation(transformation_id)

    {:noreply, socket}
  end

  def handle_event("toggle-component-visibility", _, socket) do
    current_visibility = Map.get(socket.assigns, :visible?)

    {:noreply, assign(socket, visible?: not current_visibility)}
  end

  defp transformation_name(form) do
    name_field_value = input_value(form, :name)

    if(blank?(name_field_value)) do
      "New Transformation"
    else
      name_field_value
    end
  end

  defp blank?(str_or_nil), do: "" == str_or_nil |> to_string() |> String.trim()

  defp get_fields(transformation_type) do
    TransformationFields.fields_for(transformation_type)
  end
end
