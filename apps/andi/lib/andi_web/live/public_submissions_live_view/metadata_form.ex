defmodule AndiWeb.SubmitLiveView.MetadataForm do
  @moduledoc """
    LiveComponent for public submissions of dataset metadata
  """
  use Phoenix.LiveView
  use AndiWeb.FormSection, schema_module: AndiWeb.InputSchemas.SubmissionMetadataFormSchema
  import Phoenix.HTML.Form

  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.InputSchemas.SubmissionMetadataFormSchema
  alias AndiWeb.Helpers.MetadataFormHelpers
  alias AndiWeb.Helpers.FormTools

  def mount(_, %{"dataset" => dataset}, socket) do
    new_metadata_changeset = SubmissionMetadataFormSchema.changeset_from_andi_dataset(dataset)

    send(socket.parent_pid, {:update_metadata_status, new_metadata_changeset.valid?})

    dataset_published? = dataset.submission_status == :published

    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")
    AndiWeb.Endpoint.subscribe("source-format")

    {:ok,
     assign(socket,
       dataset_published?: dataset_published?,
       dataset_id: dataset.id,
       visibility: "expanded",
       validation_status: "expanded",
       changeset: new_metadata_changeset
     )}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
    <div id="metadata-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility">
        <div class="section-number">
          <h3 class="component-number component-number--<%= @validation_status %> component-number--<%= @visibility %>">1</h3>
          <div class="component-number-status--<%= @validation_status %>"></div>
        </div>

        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %>">Enter Metadata</h2>
          <button type="button" class="btn btn--right btn--transparent">
            <div class="component-title-action">
              <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
              <div class="component-title-icon--<%= @visibility %>"></div>
            </div>
          </button>
        </div>
      </div>

      <div class="form-section">
        <%= f = form_for @changeset, "#", [phx_change: :validate, phx_submit: :save, as: :form_data] %>
        <%= hidden_input(f, :dataName) %>

          <div class="component-edit-section--<%= @visibility %>">
            <div class="section-help">
              <a href="https://prod-os-public-data.s3-us-west-2.amazonaws.com/andi/instructions.pdf" class="primary-color document-link" target="_blank">How to Complete the Metadata Section <span class="link-out"></span></a>
            </div>
            <div class="submission-metadata-form-edit-section form-grid">
              <div class="metadata-form__title">
                <%= label(f, :dataTitle, DisplayNames.get(:dataTitle), class: "label label--required") %>
                <%= text_input(f, :dataTitle, [class: "input", phx_value_field: "dataTitle", phx_debounce: "1000", required: true]) %>
                <%= ErrorHelpers.error_tag(f, :dataTitle, bind_to_input: false) %>
              </div>

              <div class="metadata-form__description">
                <%= label(f, :description, DisplayNames.get(:description), class: "label label--required") %>
                <%= textarea(f, :description, [class: "input textarea", required: true]) %>
                <%= ErrorHelpers.error_tag(f, :description, bind_to_input: false) %>
              </div>

              <div class="metadata-form__format">
                <%= label(f, :sourceFormat, DisplayNames.get(:sourceFormat), class: "label label--required") %>
                <%= select(f, :sourceFormat, MetadataFormHelpers.get_source_format_options(input_value(f, :sourceType)), [class: "select", disabled: @dataset_published?, required: true]) %>
                <%= ErrorHelpers.error_tag(f, :sourceFormat, bind_to_input: false) %>
              </div>

              <div class="metadata-form__maintainer-name">
                <%= label(f, :contactName, DisplayNames.get(:contactName), class: "label label--required") %>
                <%= text_input(f, :contactName, class: "input", required: true) %>
                <%= ErrorHelpers.error_tag(f, :contactName, bind_to_input: false) %>
              </div>

              <div class="metadata-form__keywords">
                <%= label(f, :keywords, DisplayNames.get(:keywords), class: "label") %>
                <%= text_input(f, :keywords, [value: MetadataFormHelpers.keywords_to_string(input_value(f, :keywords)), class: "input", required: true]) %>
                <div class="label label--inline">Separated by comma</div>
              </div>

              <div class="metadata-form__spatial">
                <div class="help-text-label">
                  <%= label(f, :spatial, DisplayNames.get(:spatial), class: "label") %>
                  <a href="https://resources.data.gov/resources/dcat-us/#spatial" target="_blank">Formatting Help</a>
                </div>
                <%= text_input(f, :spatial, class: "input") %>
              </div>

              <div class="metadata-form__temporal">
                <div class="help-text-label">
                  <%= label(f, :temporal, DisplayNames.get(:temporal), class: "label") %>
                  <a href="https://resources.data.gov/resources/dcat-us/#temporal" target="_blank">Formatting Help</a>
                </div>
                <%= text_input(f, :temporal, class: "input") %>
                <%= ErrorHelpers.error_tag(f, :temporal) %>
              </div>

              <div class="metadata-form__language">
                <%= label(f, :language, DisplayNames.get(:language), class: "label") %>
                <%= select(f, :language, MetadataFormHelpers.get_language_options(), value: MetadataFormHelpers.get_language(input_value(f, :language)), class: "select") %>
              </div>

              <div class="metadata-form__homepage">
                <%= label(f, :homepage, DisplayNames.get(:homepage), class: "label") %>
                <%= text_input(f, :homepage, class: "input") %>
              </div>
            </div>

            <div class="edit-button-group form-grid">
              <div class="edit-button-group__cancel-btn">
                <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
              </div>

              <div class="edit-button-group__save-btn">
                <a href="#data_dictionary_form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-expand="data_dictionary_form">Next</a>
              </div>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  def handle_event(
        "validate",
        %{"form_data" => form_data, "_target" => ["form_data", "dataTitle" | _]},
        %{assigns: %{dataset_published?: false}} = socket
      ) do
    form_data
    |> FormTools.adjust_data_name()
    |> SubmissionMetadataFormSchema.changeset_from_form_data()
    |> send_metadata_status(socket)
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> SubmissionMetadataFormSchema.changeset_from_form_data()
    |> send_metadata_status(socket)
    |> complete_validation(socket)
  end

  def handle_info(
        %{topic: "toggle-visibility", payload: %{expand: "metadata_form", dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    {:noreply, assign(socket, visibility: "expanded") |> update_validation_status()}
  end

  def handle_info(%{topic: "toggle-visibility"}, socket) do
    {:noreply, socket}
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset) |> update_validation_status()}
  end

  defp send_metadata_status(changeset, socket) do
    send(socket.parent_pid, {:update_metadata_status, changeset.valid?})
    changeset
  end
end
