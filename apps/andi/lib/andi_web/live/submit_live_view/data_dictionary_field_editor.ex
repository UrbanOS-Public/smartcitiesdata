defmodule AndiWeb.SubmitLiveView.DataDictionaryFieldEditor do
  @moduledoc """
    LiveComponent for a nested data dictionary tree view
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Helpers.DataDictionaryHelpers

  def mount(socket) do
    {:ok, assign(socket, expansion_map: %{})}
  end

  def render(assigns) do
    id = Atom.to_string(assigns.id)
    form_with_errors = DataDictionaryHelpers.add_errors_to_form(assigns.form)
    field_type = input_value(assigns.form, :type)

    ~L"""
      <div id="<%= @id %>" class="data-dictionary-field-editor" >
        <%= hidden_input(@form, :id, id: id <> "_id") %>
        <%= hidden_input(@form, :bread_crumb) %>
        <%= hidden_input(@form, :dataset_id) %>

        <div class="data-dictionary-field-editor__name">
          <%= label(@form, :name, "Name", class: "label label--required") %>
          <%= text_input(@form, :name, id: id <> "_name", class: "data-dictionary-field-editor__name input", "phx-debounce": "1000") %>
          <%= ErrorHelpers.error_tag(form_with_errors, :name) %>
        </div>
        <div class="data-dictionary-field-editor__selector">
          <%= label(@form, :name, "Selector", class: "label label--required") %>
          <%= text_input(@form, :selector, id: id <> "_name", class: "data-dictionary-field-editor__selector input", disabled: !DataDictionaryHelpers.is_source_format_xml(@source_format)) %>
          <%= ErrorHelpers.error_tag(form_with_errors, :selector) %>
        </div>
        <div class="data-dictionary-field-editor__type">
          <%= label(@form, :type, "Type", class: "label label--required") %>
          <%= select(@form, :type, DataDictionaryHelpers.get_item_types(), id: id <> "_type", class: "data-dictionary-field-editor__type select") %>
          <%= ErrorHelpers.error_tag(form_with_errors, :type) %>
        </div>

      <div class="data-dictionary-field-editor__type-info">
        <%= if field_type == "list" do %>
          <%= label(@form, :itemType, "Item Type", class: "label label--required") %>
          <%= select(@form, :itemType, DataDictionaryHelpers.get_item_types(@form), id: id <> "_item_type", class: "data-dictionary-field-editor__item-type select") %>
          <%= ErrorHelpers.error_tag(form_with_errors, :itemType) %>
        <% end %>

        <%= if field_type in ["date", "timestamp"] do %>
          <div class="format-label">
            <%= label(@form, :format, "Format", class: "label label--required") %>
            <a href="https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html" target="_blank">Help</a>
          </div>
          <%= text_input(@form, :format, id: id <> "_format", class: "data-dictionary-field-editor__format input") %>
          <%= ErrorHelpers.error_tag(form_with_errors, :format) %>
        <% end %>
      </div>

        <div class="data-dictionary-field-editor__description">
          <%= label(@form, :description, "Description", class: "label") %>
          <%= textarea(@form, :description, id: id <> "_description", class: "data-dictionary-field-editor__description input textarea", "phx-debounce": "blur") %>
        </div>
      </div>
    """
  end
end
