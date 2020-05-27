defmodule AndiWeb.EditLiveView.DataDictionaryForm do
  @moduledoc """
  LiveComponent for editing dataset schema
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Phoenix.HTML.Link
  alias AndiWeb.EditLiveView.DataDictionaryTree
  alias AndiWeb.EditLiveView.DataDictionaryFieldEditor

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~L"""
    <div id="data-dictionary-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="data_dictionary_form">
        <h3 class="component-number component-number--<%= @visibility %>">2</h3>
        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %> ">Data Dictionary</h2>
          <div class="component-title-edit-icon"></div>
        </div>
      </div>

      <div class="form-section">
        <div class="component-edit-section--<%= @visibility %>">
          <div class="data-dictionary-form-edit-section form-grid">
            <div class="data-dictionary-form__tree-section">
              <div class="data-dictionary-form__tree-header data-dictionary-form-tree-header">
                <div class="label">Enter/Edit Fields</div>
                <div class="label label--inline">TYPE</div>
              </div>

              <div class="data-dictionary-form__tree-content data-dictionary-form-tree-content">
                <%= live_component(@socket, DataDictionaryTree, id: :data_dictionary_tree, root_id: :data_dictionary_tree, form: @technical, field: :schema, selected_field_id: @selected_field_id, new_field_initial_render: @new_field_initial_render) %>
              </div>

              <div class="data-dictionary-form__tree-footer data-dictionary-form-tree-footer" >
                <div class="data-dictionary-form__add-field-button" phx-click="add_data_dictionary_field"></div>
                <div class="data-dictionary-form__remove-field-button" phx-click="remove_data_dictionary_field" phx-target="#dataset-edit-page"></div>
              </div>
            </div>

            <div class="data-dictionary-form__edit-section">
              <%= live_component(@socket, DataDictionaryFieldEditor, id: :data_dictionary_field_editor, form: @current_data_dictionary_item) %>
            </div>
          </div>

          <div class="edit-button-group form-grid">
            <div class="edit-button-group__cancel-btn">
              <a href="#metadata-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-expand="metadata_form" phx-value-component-collapse="data_dictionary_form">Back</a>
              <%= Link.button("Cancel", to: "/", method: "get", class: "btn btn--large") %>
            </div>

            <div class="edit-button-group__messages">
              <%= if @save_success do %>
                <div id="success-message" class="metadata__success-message"><%= @success_message %></div>
              <% end %>
              <%= if @has_validation_errors do %>
                <div id="validation-error-message" class="metadata__error-message">There were errors with the dataset you tried to submit.</div>
              <% end %>
              <%= if @page_error do %>
                <div id="page-error-message" class="metadata__error-message">A page error occurred</div>
              <% end %>
            </div>

            <div class="edit-button-group__save-btn">
              <a href="#url-form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-expand="url_form" phx-value-component-collapse="data_dictionary_form">Next</a>
              <%= submit("Save", id: "save-button", name: "save-button", class: "btn btn--save btn--large", phx_value_action: "draft") %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
