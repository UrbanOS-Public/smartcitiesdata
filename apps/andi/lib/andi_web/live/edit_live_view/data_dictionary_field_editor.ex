defmodule AndiWeb.EditLiveView.DataDictionaryFieldEditor do
  @moduledoc """
    LiveComponent for a nested data dictionary tree view
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Andi.InputSchemas.Options

  def mount(socket) do
    {:ok, assign(socket, expansion_map: %{})}
  end

  def render(assigns) do
    id = Atom.to_string(assigns.id)

    ~L"""
      <div id="<%= @id %>" class="data-dictionary-field-editor" >
        <%= hidden_input(@form, :id, id: id <> "_id") %>
        <div class="data-dictionary-field-editor__name">
          <%= label(@form, :name, "Name", class: "label label--required") %>
          <%= text_input(@form, :name, id: id <> "_name", class: "data-dictionary-field-editor__name input", "phx-debounce": "1000") %>
        </div>
        <div class="data-dictionary-field-editor__type">
          <%= label(@form, :type, "Type", class: "label label--required") %>
          <%= select(@form, :type, get_item_types(), id: id <> "_type", class: "data-dictionary-field-editor__type select") %>
        </div>
        <div class="data-dictionary-field-editor__item-type">
          <%= label(@form, :itemType, "Item Type", class: "label label--required") %>
          <%= select(@form, :itemType, get_item_types(@form), id: id <> "_item_type", class: "data-dictionary-field-editor__item-type select", disabled: is_type_not_list(@form)) %>
        </div>
        <div class="data-dictionary-field-editor__description">
          <%= label(@form, :description, "Description", class: "label") %>
          <%= textarea(@form, :description, id: id <> "_description", class: "data-dictionary-field-editor__description input textarea", "phx-debounce": "blur") %>
        </div>
        <div class="data-dictionary-field-editor__pii">
          <%= label(@form, :pii, "P.I.I.", class: "label") %>
          <%= select(@form, :pii, get_pii_types(), id: id <> "_pii", class: "data-dictionary-field-editor__pii select") %>
        </div>
        <div class="data-dictionary-field-editor__masked">
          <%= label(@form, :masked, "De-Identified", class: "label") %>
          <%= select(@form, :masked, get_masked_types(), id: id <> "_masked", class: "data-dictionary-field-editor__masked select") %>
        </div>
        <div class="data-dictionary-field-editor__demographic">
          <%= label(@form, :demographic, "Demographic Traits", class: "label") %>
          <%= select(@form, :demographic, get_demographic_traits(), id: id <> "_demographic", class: "data-dictionary-field-editor__demographic select") %>
        </div>
        <div class="data-dictionary-field-editor__biased">
          <%= label(@form, :biased, "Potentially Biased", class: "label") %>
          <%= select(@form, :biased, get_biased_types(), id: id <> "_biased", class: "data-dictionary-field-editor__biased select") %>
        </div>
        <div class="data-dictionary-field-editor__rationale">
          <%= label(@form, :rationale, "Rationale", class: "label") %>
          <%= text_input(@form, :rationale, id: id <> "_rationale", class: "data-dictionary-field-editor__rationale input", "phx-debounce": "1000") %>
        </div>
      </div>
    """
  end

  defp get_item_types(), do: map_to_dropdown_options(Options.items())
  defp get_item_types(field), do: map_to_dropdown_options(field, Options.items())
  defp get_pii_types(), do: map_to_dropdown_options(Options.pii())
  defp get_masked_types(), do: map_to_dropdown_options(Options.masked())
  defp get_demographic_traits(), do: map_to_dropdown_options(Options.demographic_traits())
  defp get_biased_types(), do: map_to_dropdown_options(Options.biased())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  defp map_to_dropdown_options(field, options) do
    case input_value(field, :type) do
      "list" -> Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
      _ -> []
    end
  end

  defp is_type_not_list(field) do
    input_value(field, :type) != "list"
  end
end
