defmodule AndiWeb.SubmitLiveView.DatasetLink do
  @moduledoc """
  LiveComponent for editing dataset link in the self service UI
  """
  use Phoenix.LiveView
  use AndiWeb.FormSection, schema_module: Andi.InputSchemas.Datasets.Dataset
  import Phoenix.HTML
  import Phoenix.HTML.Form
  require Logger
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.InputSchemas.UrlFormSchema
  alias AndiWeb.Helpers.FormTools
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.Dataset

  def mount(_, %{"dataset" => dataset}, socket) do
    new_changeset = Dataset.submission_changeset(dataset, %{})

    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       changeset: new_changeset,
       visibility: "collapsed",
       validation_status: "collapsed",
       dataset_id: dataset.id
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
          <div class="section-number">
            <h3 class="component-number component-number--<%= @validation_status %>">3</h3>
            <div class="component-number-status--<%= @validation_status %>"></div>
          </div>
          <div class="component-title full-width">
            <h2 class="component-title-text component-title-text--<%= @visibility %> ">Dataset Link</h2>
            <div class="component-title-action">
              <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
              <div class="component-title-icon--<%= @visibility %>"></div>
            </div>
          </div>
        </div>

        <div class="form-section">
          <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data] %>
            <div class="component-edit-section--<%= @visibility %>">
              <div class="url-form-header">
                <h4><span class="header">Provide the link to where your dataset is hosted*</span></h4>
                <h4>To prevent the potential ingestion of Personally Identifiable Information (PII) in the Smart Columbus Operating System, your dataset must be hosted in a cloud envinronment and sharable in order to allow our Data Curator to review. Suitable locations include <a href="#" target="_blank">Dropbox</a>, <a href="#" target="_blank">Google Drive</a>, <a href="#" target="_blank">Apple iCloud</a>, and <a href="#" target="_blank">Microsoft OneDrive</a>. Please copy the shareable link to your dataset (including any query parameters) and paste in the field below.</h4>
              </div>
              <div class="url-form-edit-section form-grid">
                <div class="url-form__source-url">
                  <%= text_input(f, :datasetLink, class: "input full-width", placeholder: "Enter the link to where your dataset is hosted here") %>
                  <%= ErrorHelpers.error_tag(f, :datasetLink, bind_to_input: false) %>
                </div>
              </div>

              <div class="edit-button-group form-grid">
                <div class="edit-button-group__cancel-btn">
                  <a href="#data-dictionary-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-expand="data_dictionary_form">Back</a>
                  <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
                </div>

                <div class="edit-button-group__save-btn">
                  <a href="#finalize_form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-expand="finalize_form">Next</a>
                  <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="save">Save Draft</button>
                </div>
                </div>
            </div>
          </form>
        </div>
      </div>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> Dataset.submission_changeset()
    |> complete_validation(socket)
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def handle_event("save-link", _, socket) do
    send(socket.parent_pid, :save)

    {:noreply, socket}
  end

  def handle_info(
        %{topic: "toggle-visibility", payload: %{expand: "url_form", dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    {:noreply, assign(socket, visibility: "expanded") |> update_validation_status()}
  end

  def handle_info(%{topic: "toggle-visibility"}, socket) do
    {:noreply, socket}
  end

  def handle_info(message, socket) do
    Logger.debug(inspect(message))
    {:noreply, socket}
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset) |> update_validation_status()}
  end
end
