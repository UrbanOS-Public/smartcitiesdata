defmodule AndiWeb.EditLiveView.UrlForm do
  @moduledoc """
  LiveComponent for editing dataset URL
  """
  use Phoenix.LiveView
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias Andi.InputSchemas.DisplayNames
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias Andi.InputSchemas.Form.Url

  def mount(_, %{"dataset" => dataset}, socket) do
    new_changeset = Url.changeset_from_andi_dataset(dataset) |> IO.inspect()

    {:ok,
     assign(socket,
       changeset: new_changeset,
       testing: false,
       test_results: nil,
       visibility: "expanded"
     )}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
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
          <%= f = form_for @changeset, "#", [phx_change: :cam, as: :form_data] %>
          <div class="component-edit-section--<%= @visibility %>">
            <div class="url-form-edit-section form-grid">
              <div class="url-form__source-url">
                <%= label(f, :sourceUrl, DisplayNames.get(:sourceUrl), class: "label label--required") %>
                <%= text_input(f, :sourceUrl, class: "input full-width", disabled: @testing) %>
                <%= ErrorHelpers.error_tag(f, :sourceUrl) %>
              </div>

              <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_query_params, css_label: "source-query-params", form: f, field: :sourceQueryParams ) %>
              <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_headers, css_label: "source-headers", form: f, field: :sourceHeaders ) %>

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
                <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
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
