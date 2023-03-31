defmodule AndiWeb.IngestionLiveView.Transformations.TransformationForm do
  @moduledoc """
  LiveComponent for editing an individual transformation
  """
  use Phoenix.LiveComponent

  require Logger
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias Ecto.Changeset
  alias Andi.InputSchemas.Ingestions.Transformation
  alias AndiWeb.IngestionLiveView.Transformations.TransformationFieldBuilder

  def mount(socket) do
    {:ok,
     assign(socket,
       visible?: false,
       condition?: nil,
       static?: nil,
       date?: false
     )}
  end

  def render(assigns) do
    visible = if assigns.visible?, do: "expanded", else: "collapsed"
    show_condition_fields = not is_nil(assigns.condition?) and assigns.condition?
    show_regular_fields = not is_nil(assigns.condition?) and not assigns.condition?

    ~L"""
    <%= f = form_for @transformation_changeset, "#", [ as: :form_data, phx_change: :validate, phx_target: @myself, id: @id, class: "transformation-item"] %>
      <div class="transformation-header full-width" id="transformation_<%= @id %>__header" phx-click="toggle-component-visibility" phx-target="<%= @myself %>">
        <h3 class="transformation-header-name"> <%= transformation_name(f) %> </h3>
        <div class="transformation-actions">
          <button class="material-icons transformation-action delete-transformation-button delete-<%= @transformation_changeset.changes.id %>" type="button" phx-click="delete-transformation" phx-value-id="<%= @transformation_changeset.changes.id %>" phx-target="<%= @myself %>" aria-label="Delete Transformation">delete_outline</button>
          <button class="material-icons transformation-action" type="button" aria-label="Edit Transformation">edit</button>
          <% {_, transformation_changeset_id} = Changeset.fetch_field(@transformation_changeset, :id) %>
          <button class="material-icons transformation-action move-button move-up" type="button" phx-click="move-transformation" phx-value-id="<%= transformation_changeset_id %>" phx-value-move-index="-1" phx-target="<%= @myself %>" aria-label="Move Transformation up">arrow_upward</button>
          <button class="material-icons transformation-action move-button move-down" type="button" phx-click="move-transformation" phx-value-id="<%= transformation_changeset_id %>" phx-value-move-index="1" phx-target="<%= @myself %>" aria-label="Move Transformation down">arrow_downward</button>
        </div>
      </div>

      <div class="transformation-form transformation-form__section--<%= visible %>">
        <div class="transformation-form__name">
          <%= label(f, :name, "Name", class: "label label--required", for: "transformation_#{@id}__name") %>
          <%= text_input(f, :name, [id: "transformation_#{@id}__name", class: "transformation-name input transformation-form-fields", required: true, aria_label: "Transformation Name"]) %>
          <%= ErrorHelpers.error_tag(f, :name, bind_to_input: false, id: "#{@id}_transformation_name_error") %>
        </div>
        <fieldset style="border:none; padding-left: 0;">
          <legend class="label" style="margin-top: 1em;">When should this transformation apply?</legend>
            <div class="transformation-form__condition-radio">
              <%= radio_button(f, :condition, false, id: "transformation_#{@id}__condition_always", for: "transformation_#{@id}__condition", checked: show_regular_fields) %>
              <%= label(f, :condition, "Always", for: "transformation_#{@id}__condition") %>
            </div>
            <div class="transformation-form__condition-radio">
              <%= radio_button(f, :condition, true, id: "transformation_#{@id}__condition_specific", for: "transformation_#{@id}__condition", checked: show_condition_fields) %>
              <%= label(f, :condition, "Under a specific condition",  for: "transformation_#{@id}__condition") %>
            </div>
        </fieldset>
        <%= if show_condition_fields do %>
          <div>
            <%= TransformationFieldBuilder.build_condition_form(assigns, f) %>
          </div>
        <% end %>
        <%= if show_regular_fields do %>
          <div>
            <%= TransformationFieldBuilder.build_transformation_form(assigns, f, false) %>
          </div>
        <% end %>
      </div>
    </form>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    show_condition? = check_form_data(form_data, "condition", "true")
    show_static_value? = check_form_data(form_data, "conditionCompareTo", "Static Value")
    show_date_fields? = check_form_data(form_data, "conditionDataType", "DateTime")

    transformation = Transformation.changeset(socket.assigns.transformation_changeset, form_data)

    AndiWeb.IngestionLiveView.Transformations.TransformationsStep.update_transformation(transformation, socket.assigns.id)

    {:noreply, assign(socket, condition?: show_condition?, static?: show_static_value?, date?: show_date_fields?)}
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

    parameters =
      case Changeset.fetch_field(socket.assigns.transformation_changeset, :parameters) do
        {_, parameters} -> parameters
        :error -> %{}
      end

    condition_select =
      case Map.get(parameters, :condition) do
        nil -> nil
        "true" -> true
        "false" -> false
      end

    static =
      case Map.get(parameters, :conditionCompareTo) do
        nil -> nil
        "Static Value" -> true
        "Target Field" -> false
      end

    show_date =
      case Map.get(parameters, :conditionDataType) do
        nil -> false
        "DateTime" -> true
      end

    {:noreply, assign(socket, visible?: not current_visibility, condition?: condition_select, static?: static, date?: show_date)}
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

  defp check_form_data(data, param, compare_val) do
    value = Map.get(data, param)
    if is_nil(value), do: nil, else: if(value == "", do: nil, else: value == compare_val)
  end
end
