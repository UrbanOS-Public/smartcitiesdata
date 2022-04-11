defmodule AndiWeb.DataDictionary.Tree do
  @moduledoc """
    LiveComponent for a nested data dictionary tree view
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML
  import Phoenix.HTML.Form

  alias AndiWeb.DataDictionary.Tree

  def mount(socket) do
    {:ok, assign(socket, expansion_map: %{})}
  end

  def render(assigns) do
    if assigns.selected_field_id == :no_dictionary do
      assign_current_dictionary_field(:no_dictionary, nil, nil, nil)
    end

    ~L"""
    <%= if is_set?(@form, @field) do %>
      <div id="<%= @id %>" class="data-dictionary-tree data-dictionary-tree--<%= tree_modifier(@field) %>">
        <%= for field <- inputs_for(@form, @field) do %>
        <% if input_value(field, :id) == @selected_field_id and @new_field_initial_render, do: assign_current_dictionary_field(input_value(field, :id), field.index, field.name, field.id) %>
          <%= hidden_inputs(field, @selected_field_id) %>
          <%= hidden_input(field, :dataset_id) %>

          <% {icon_modifier, selected_modifier} = get_action(field, assigns) %>

          <div class="data-dictionary-tree-field data-dictionary-tree__field data-dictionary-tree__field--<%= icon_modifier %> data-dictionary-tree__field--<%= selected_modifier %>">
          <div class="data-dictionary-tree-field__action" phx-click="<%= if is_set?(field, :subSchema), do: "toggle_expanded", else: "toggle_selected" %>" phx-value-field-id="<%= input_value(field, :id) %>" phx-value-index="<%= field.index %>" phx-value-name="<%= field.name %>" phx-value-id="<%= field.id %>" phx-target="#<%= @root_id %>"></div>
          <div class="data-dictionary-tree-field__text" phx-click="toggle_selected" phx-value-field-id="<%= input_value(field, :id) %>" phx-value-index="<%= field.index %>" phx-value-name="<%= field.name %>" phx-value-id="<%= field.id %>" phx-target="#<%= @root_id %>">
              <div class="data-dictionary-tree-field__name data-dictionary-tree-field-attribute"><%= input_value(field, :name) %></div>
              <div class="data-dictionary-tree-field__type data-dictionary-tree-field-attribute"><%= input_value(field, :type) %></div>
            </div>
          </div>

          <%= if is_set?(field, :subSchema) do %>
            <div class="data-dictionary-tree__sub-dictionary data-dictionary-tree__sub-dictionary--<%= icon_modifier %>">
              <%= live_component(@socket, Tree, id: :"#{@id}_#{input_value(field, :name)}", root_id: @root_id, selected_field_id: @selected_field_id, form: field, field: :subSchema, expansion_map: @expansion_map, new_field_initial_render: @new_field_initial_render, add_field_event_name: @add_field_event_name) %>
            </div>
          <% end %>
        <% end %>
      </div>
    <% else %>
      <%= content_for_empty_schema(@field, @add_field_event_name) %>
    <% end %>
    """
  end

  def handle_event("toggle_expanded", %{"field-id" => field_id}, %{assigns: %{expansion_map: expansion_map}} = socket) do
    updated_expansion_map = toggle_expansion(field_id, expansion_map)

    {:noreply, assign(socket, expansion_map: updated_expansion_map)}
  end

  def handle_event("toggle_selected", %{"field-id" => field_id, "index" => index, "name" => name, "id" => id}, socket) do
    assign_current_dictionary_field(field_id, index, name, id)
    {:noreply, assign(socket, selected_field_id: field_id, new_field_initial_render: false)}
  end

  defp assign_current_dictionary_field(field_id, index, name, id) do
    send(self(), {:assign_editable_dictionary_field, field_id, index, name, id})
  end

  defp toggle_expansion(field_id, expansion_map) do
    toggled = not expanded?(field_id, expansion_map)

    Map.put(expansion_map, field_id, toggled)
  end

  defp expanded?(id, expansion_map) do
    Map.get(expansion_map, id, true)
  end

  defp get_action(field, assigns) do
    %{
      expansion_map: expansion_map,
      selected_field_id: selected_field_id
    } = assigns

    id = input_value(field, :id)

    icon_modifier =
      if is_set?(field, :subSchema) do
        if expanded?(id, expansion_map) do
          "expanded"
        else
          "collapsed"
        end
      else
        if id == selected_field_id do
          "checked"
        else
          "unchecked"
        end
      end

    selected_modifier =
      if id == selected_field_id do
        "selected"
      else
        "unselected"
      end

    {icon_modifier, selected_modifier}
  end

  defp is_set?(%{source: changeset}, field) do
    case Ecto.Changeset.fetch_field(changeset, field) do
      :error -> false
      {:data, []} -> false
      {:changes, []} -> false
      _ -> true
    end
  end

  defp tree_modifier(:schema), do: "top-level"
  defp tree_modifier(_), do: "sub-level"

  defp content_for_empty_schema(:schema, add_field_event_name) do
    assigns = %{
      event_name: add_field_event_name
    }

    ~E"""
      <div class="data-dictionary-tree__getting-started-help">
        <span>Click the&nbsp;</span>
        <span class="data-dictionary-form__add-field-button" phx-click="<%= @event_name %>"></span>
        <span>&nbsp;button below to add a new field or <a phx-click="<%= @event_name %>">Click here...</a></span>
      </div>
    """
  end

  defp content_for_empty_schema(_field_name, _event_name), do: ""

  defp hidden_inputs(form_field, selected_field_id) do
    if input_value(form_field, :id) != selected_field_id do
      form_field.data.__struct__.__schema__(:fields)
      |> List.delete(:parent_id)
      |> List.delete(:technical_id)
      |> List.delete(:dataset_id)
      |> List.delete(:ingestion_id)
      |> Enum.map(fn k ->
        hidden_input(form_field, k)
      end)
    end
  end
end
