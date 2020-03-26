defmodule AndiWeb.EditLiveView.DataDictionaryTree do
  @moduledoc """
    LiveComponent for a nested data dictionary tree view
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias AndiWeb.EditLiveView.DataDictionaryTree

  def mount(socket) do
    {:ok, assign(socket, expansion_map: %{}, checked_field_id: :unassigned)}
  end

  def render(assigns) do
    ~L"""
    <%= if is_set?(@form, @field) do %>
    <div id="<%= @id %>" class="data-dictionary-tree">
      <%= for field <- inputs_for(@form, @field) do %>
        <%= hidden_input(field, :id) %> 
        <%= hidden_input(field, :name) %> 
        <%= hidden_input(field, :type) %> 
      <% {icon_modifier, selected_modifier} = get_action(field, assigns) %>
      <div class="data-dictionary-tree-field data-dictionary-tree__field data-dictionary-tree__field--<%= icon_modifier %> data-dictionary-tree__field--<%= selected_modifier %>">
        <div phx-click="<%= if is_set?(field, :subSchema), do: "toggle_expanded", else: "toggle_checked" %>" phx-value-field-id="<%= input_value(field, :id) %>" phx-target="#<%= @root_id %>" class="data-dictionary-tree-field__action data-dictionary-tree-field__action"></div>
        <div class="data-dictionary-tree-field__text" phx-click="toggle_checked" phx-value-field-id="<%= input_value(field, :id) %>" phx-target="#<%= @root_id %>">
          <div class="data-dictionary-tree-field__name data-dictionary-tree-field-attribute"><%= input_value(field, :name) %></div>
          <div class="data-dictionary-tree-field__type data-dictionary-tree-field-attribute"><%= input_value(field, :type) %></div>
        </div>
      </div>
      <div class="data-dictionary-tree__sub-dictionary data-dictionary-tree__sub-dictionary--<%= icon_modifier %>">
        <%= live_component(@socket, DataDictionaryTree, id: :"#{@id}_#{input_value(field, :name)}", root_id: @root_id, checked_field_id: @checked_field_id, form: field, field: :subSchema, expansion_map: @expansion_map) %>
      </div>
      <% end %>
    </div>
    <% end %>
    """
  end

  def handle_event("toggle_expanded", %{"field-id" => field_id}, %{assigns: %{expansion_map: expansion_map}} = socket) do
    updated_expansion_map = toggle_expansion(field_id, expansion_map)

    {:noreply, assign(socket, expansion_map: updated_expansion_map)}
  end

  def handle_event("toggle_checked", %{"field-id" => field_id}, %{assigns: %{checked_field_id: checked_field_id}} = socket) do
    updated_checked_field_id = toggle_check(field_id, checked_field_id)

    # send(self(), {:toggle_checked, updated_checked_field_id})

    {:noreply, assign(socket, checked_field_id: updated_checked_field_id)}
  end

  defp toggle_check(field_id, checked_field_id) do
    # if field_id == checked_field_id do
    #   :unassigned
    # else
    field_id
    # end
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
      checked_field_id: checked_field_id
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
        if id == checked_field_id do
          "checked"
        else
          "unchecked"
        end
      end

    selected_modifier =
      if id == checked_field_id do
        send(self(), {:assign_editable_dictionary_field, field})
        "selected"
      else
        "unselected"
      end

    {icon_modifier, selected_modifier}
  end

  defp is_set?(%{source: %{changes: changes}}, field), do: changes[field] != nil
end
