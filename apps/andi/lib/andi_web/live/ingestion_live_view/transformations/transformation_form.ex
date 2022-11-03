defmodule AndiWeb.IngestionLiveView.Transformations.TransformationForm do
  @moduledoc """
  LiveComponent for editing an individual transformation
  """
  use Phoenix.LiveView
  use Phoenix.LiveComponent

  require Logger
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Ingestions.Transformation
  alias Andi.InputSchemas.Ingestions.Transformations
  alias AndiWeb.IngestionLiveView.Transformations.TransformationFieldBuilder
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.Helpers.MetadataFormHelpers
  alias Transformers.TransformationFields

  def mount(_params, %{"transformation_changeset" => transformation_changeset}, socket) do
    AndiWeb.Endpoint.subscribe("form-save")

    transformation_type = Map.get(transformation_changeset.changes, :type)

    {:ok,
     assign(socket,
       transformation_changeset: transformation_changeset,
       visibility: "collapsed",
       transformation_type: transformation_type
     )}
  end

  def render(assigns) do
    ~L"""
    <%= f = form_for @transformation_changeset, "#", [ as: :form_data, phx_change: :validate, class: "transformation-item"] %>
        <div class="transformation-header full-width" phx-click="toggle-component-visibility" phx-value-component="transformations_form">
          <h3 class="transformation-header-name"> <%= transformation_name(f) %> </h3>
          <div class="transformation-actions">
            <button class="material-icons transformation-action delete-transformation-button delete-<%= @transformation_changeset.changes.id %>" type="button" phx-click="delete-transformation" phx-value-id=<%= @transformation_changeset.changes.id %> phx-target="#transformations-form">delete_outline</button>
            <button class="material-icons transformation-action" type="button">edit</button>
            <button class="material-icons transformation-action move-button move-up move-up-<%= @transformation_changeset.changes.id %>" type="button" phx-click="move-transformation" phx-value-id=<%= @transformation_changeset.changes.id %> phx-value-move-index="-1" phx-target="#transformations-form">arrow_upward</button>
            <button class="material-icons transformation-action move-button move-down move-down-<%= @transformation_changeset.changes.id %>" type="button" phx-click="move-transformation" phx-value-id=<%= @transformation_changeset.changes.id %> phx-value-move-index="1" phx-target="#transformations-form">arrow_downward</button>
          </div>
        </div>
        <%= hidden_input(f, :id, value: @transformation_changeset.changes.id) %>
        <div class="transformation-form transformation-edit-form--<%= @visibility %>">
          <div class="transformation-form__name">
            <%= label(f, :name, "Name", class: "label label--required") %>
            <%= text_input(f, :name, [class: "transformation-name input transformation-form-fields", phx_debounce: "1000", required: true]) %>
            <%= ErrorHelpers.error_tag(f.source, :name, bind_to_input: false) %>
          </div>

          <div class="transformation-form__type">
            <%= label(f, :type, DisplayNames.get(:transformationType), class: "label label--required") %>
            <%= select(f, :type, get_transformation_types(), [phx_click: "transformation-type-selected", class: "select transformation-type", required: true]) %>
            <%= ErrorHelpers.error_tag(f.source, :type, bind_to_input: false) %>
          </div>
          <div class="transformation-form__fields">
            <%= for field <- get_fields(@transformation_type) do %>
              <%= TransformationFieldBuilder.build_input(field, assigns, f) %>
            <% end %>
          </div>
        </div>
    </form>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    new_changeset = Transformation.changeset_from_form_data(form_data)
    AndiWeb.Endpoint.broadcast_from(self(), "transformation", "changed", %{transformation_changeset: new_changeset})

    {:noreply,
     assign(socket, transformation_changeset: new_changeset, transformation_type: form_data["type"], transformation_name: form_data["name"])}
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

  def handle_event("transformation-type-selected", %{"value" => value}, socket) do
    {:noreply, assign(socket, transformation_type: value)}
  end

  def handle_info(
        %{topic: "form-save", event: "save-all", payload: %{ingestion_id: ingestion_id}},
        %{
          assigns: %{
            transformation_changeset: transformation_changeset
          }
        } = socket
      ) do
    changes =
      InputConverter.form_changes_from_changeset(transformation_changeset)
      |> Map.put(:ingestion_id, ingestion_id)

    transformation_changeset.changes.id
    |> Transformations.get()
    |> Transformations.update(changes)

    {:noreply,
     assign(socket,
       validation_status: "valid"
     )}
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

  defp get_validation_status(new_changeset) do
    if new_changeset.valid? do
      "valid"
    else
      "invalid"
    end
  end

  defp get_transformation_types(), do: map_to_dropdown_options(MetadataFormHelpers.get_transformation_type_options())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} ->
      [key: description, value: actual_value]
    end)
  end

  defp get_fields(transformation_type) do
    TransformationFields.fields_for(transformation_type)
  end
end
