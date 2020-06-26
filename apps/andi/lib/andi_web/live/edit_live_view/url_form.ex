defmodule AndiWeb.EditLiveView.UrlForm do
  @moduledoc """
  LiveComponent for editing dataset URL
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Phoenix.HTML.Link
  alias AndiWeb.ErrorHelpers
  alias Andi.InputSchemas.DisplayNames
  alias AndiWeb.EditLiveView.KeyValueEditor

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    is_visible = assigns.visibility == "expanded"

    unsaved_changes_modifier =
      if assigns.show_unsaved_changes_modal && is_visible do
        "visible"
      else
        "hidden"
      end

    ~L"""

    <div class="unsaved-changes-modal unsaved-changes-modal--<%= unsaved_changes_modifier %>">
      <div class="modal-form-container">
        <h3>Unsaved Changes</h3>
        <p class="unsaved-changes-modal__message">
          You have unsaved changes within this<br> section. Do you wish to continue without saving?
        </p>
        <br>
        <div class="button-container">
          <a href="#metadata-form" class="btn" phx-click="unsaved-changes-canceled">Cancel</a>
          <a href="#metadata-form" class="btn submit_button" phx-click="toggle-component-visibility" phx-value-component-expand="finalize_form" phx-value-component-collapse="url_form" phx-value-continue-unsaved="true">Continue</a>
        </div>
      </div>
    </div>

      <div id="url-form" class="form-component">
        <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="url_form">
          <h3 class="component-number component-number--<%= @visibility %>">3</h3>
          <div class="component-title full-width">
            <h2 class="component-title-text component-title-text--<%= @visibility %> ">Configure Upload</h2>
            <div class="component-title-action">
              <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
              <div class="component-title-icon--<%= @visibility %>"></div>
            </div>
          </div>
        </div>

        <div class="form-section">
          <div class="component-edit-section--<%= @visibility %>">
            <div class="url-form-edit-section form-grid">
              <div class="url-form__source-url">
                <%= label(@technical, :sourceUrl, DisplayNames.get(:sourceUrl), class: "label label--required") %>
                <%= text_input(@technical, :sourceUrl, class: "input full-width", disabled: @testing) %>
                <%= ErrorHelpers.error_tag(@technical, :sourceUrl) %>
              </div>

              <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_query_params, css_label: "source-query-params", form: @technical, field: :sourceQueryParams ) %>
              <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_headers, css_label: "source-headers", form: @technical, field: :sourceHeaders ) %>

              <div class="url-form__test-section">
                <button type="button" class="url-form__test-btn btn--test btn btn--large btn--action" phx-click="test_url" <%= disabled?(@testing) %>>Test</button>
                <%= if @test_results do %>
                  <div class="test-status">
                  Status: <span class="test-status__code <%= status_class(@test_results) %>"><%= @test_results |> Map.get(:status) %></span>
                  Time: <span class="test-status__time"><%= @test_results |> Map.get(:time) %></span> ms
                  </div>
                <% end %>
              </div>
            </div>

            <div class="edit-button-group form-grid">
              <div class="edit-button-group__cancel-btn">
                <a href="#data-dictionary-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-collapse="url_form" phx-value-component-expand="data_dictionary_form">Back</a>
                <%= Link.button("Cancel", to: "/", method: "get", class: "btn btn--large") %>
              </div>

              <div class="edit-button-group__save-btn">
                <a href="#finalize_form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-collapse="url_form" phx-value-component-expand="finalize_form">Next</a>
                <%= submit("Save Draft", id: "save-button", name: "save-button", class: "btn btn--save btn--large", phx_value_action: "draft") %>
              </div>
            </div>
          </div>
        </div>
      </div>
    """
  end

  defp disabled?(true), do: "disabled"
  defp disabled?(_), do: ""

  defp status_class(%{status: status}) when status in 200..399, do: "test-status__code--good"
  defp status_class(%{status: _}), do: "test-status__code--bad"
end
