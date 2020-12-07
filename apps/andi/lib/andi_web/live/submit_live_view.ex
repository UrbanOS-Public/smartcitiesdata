defmodule AndiWeb.SubmitLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Datasets.Dataset

  require Logger

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-page" id="dataset-edit-page">
      <div class="preamble">
      <p>You are about to submit a dataset to the Smart Columbus Operating System for review. If approved, your dataset will be made available to the public for download and consumption. The Smart Columbus Operating System currently does not allow any datasets that contain:</p>
      <ul>
        <li>Personally Identifiable Information (PII)</li>
        <li>Data that may be harmful to any person, group, or organization</li>
        <li>Data that may be considered critical of city infrastructure</li>
      </ul>
      <p>If your dataset contains any of the above, it will be rejected by the Data Curator. The Data Curator may also reject your dataset for reasons such as:</p>
      <ul>
        <li>Errors</li>
        <li>Inaccurate data</li>
        <li>Duplicate dataset</li>
        <li>Incomplete data</li>
        <li>Failure to complete metadata</li>
      </ul>
      <p>If your dataset is rejected, you will be notified by the Data Curator and be given an opportunity to make corrections, if applicable. After corrections are applied to the dataset (or its metadata), you as the contributor will need to re-submit the dataset for review.</p>
      <p>On the following form you will be asked to submit the metadata, a data dictionary, and a link to your dataset. This is a critical part of the ingestion process so please ensure all fields are complete and accurate.</p>
      <p>Click <a href="https://prod-os-public-data.s3-us-west-2.amazonaws.com/andi/instructions.pdf" target="_blank">HERE</a> for more guidance on how to complete this form.</p>
      </div

      <%= f = form_for @changeset, "" %>
        <%= hidden_input(f, :id) %>

        <div class="metadata-form-component">
          <%= live_render(@socket, AndiWeb.SubmitLiveView.MetadataForm, id: :metadata_form_editor, session: %{"dataset" => @dataset, "is_curator" => @is_curator}) %>
          <%= Map.get(@form_status, :metadata) %>
        </div>

        <div class="data-dictionary-form-component">
          <%= live_render(@socket, AndiWeb.EditLiveView.DataDictionaryForm, id: :data_dictionary_form_editor, session: %{"dataset" => @dataset, "is_curator" => @is_curator}) %>
          <%= Map.get(@form_status, :data_dictionary) %>
          </div>

        <div class="url-form-component">
          <%= live_render(@socket, AndiWeb.SubmitLiveView.DatasetLink, id: :dataset_link_editor, session: %{"dataset" => @dataset}) %>
          <%= Map.get(@form_status, :dataset_link) %>
        </div>
        <div class="review-submission-component">
          <%= live_render(@socket, AndiWeb.SubmitLiveView.ReviewSubmission, id: :review_submission, session: %{"dataset" => @dataset}) %>
        </div>
        <div class="submission-component">
          <div class="edit-button-group form-grid">
            <div class="edit-button-group__cancel-btn">
              <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
            </div>

            <div class="edit-button-group__save-btn">
              <button id="next-button" class="btn btn--next btn--large btn--submit" phx-click="submit" <%= if not form_valid?(@form_status), do: "disabled" %>>Submit</a>
              <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="save-all-draft">Save Draft</button>
            </div>
          </div>
        </div>
      </form>

      <%= live_component(@socket, AndiWeb.EditLiveView.UnsavedChangesModal, visibility: @unsaved_changes_modal_visibility) %>

      <div phx-hook="showSnackbar">
      <%= if @save_success do %>
        <div id="snackbar" class="success-message"><%= @success_message %></div>
      <% end %>

      <%= if @has_validation_errors do %>
        <div id="snackbar" class="error-message">There were errors with the dataset you tried to submit</div>
      <% end %>

      <%= if @page_error do %>
        <div id="snackbar" class="error-message">A page error occurred</div>
      <% end %>
    </div>
    </div>
    """
  end

  def mount(_params, %{"dataset" => dataset, "is_curator" => is_curator}, socket) do
    new_changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)
    Process.flag(:trap_exit, true)

    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       form_status: %{metadata: false, data_dictionary: false, dataset_link: false},
       changeset: new_changeset,
       dataset: dataset,
       dataset_id: dataset.id,
       is_curator: is_curator,
       has_validation_errors: false,
       new_field_initial_render: false,
       page_error: false,
       save_success: false,
       success_message: "",
       test_results: nil,
       finalize_form_data: nil,
       unsaved_changes: false,
       unsaved_changes_link: "/",
       unsaved_changes_modal_visibility: "hidden",
       publish_success_modal_visibility: "hidden",
       delete_dataset_modal_visibility: "hidden"
     )}
  end

  def handle_event("unsaved-changes-canceled", _, socket) do
    {:noreply, assign(socket, unsaved_changes_modal_visibility: "hidden")}
  end

  def handle_event("force-cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: socket.assigns.unsaved_changes_link)}
  end

  def handle_event("cancel-edit", _, socket) do
    case socket.assigns.unsaved_changes do
      true -> {:noreply, assign(socket, unsaved_changes_link: "/", unsaved_changes_modal_visibility: "visible")}
      false -> {:noreply, redirect(socket, to: "/")}
    end
  end

  def handle_event("reload-page", _, socket) do
    {:noreply, redirect(socket, to: "/datasets/#{socket.assigns.dataset.id}")}
  end

  def handle_event("submit", _, socket) do 
    dataset_id = socket.assigns.dataset.id

    AndiWeb.Endpoint.broadcast("form-save", "save-all", %{dataset_id: dataset_id})

    Process.sleep(1_000)

    andi_dataset = Datasets.get(dataset_id)

    dataset_changeset = InputConverter.andi_dataset_to_full_ui_changeset_for_publish(andi_dataset)
    dataset_for_publish = dataset_changeset |> Ecto.Changeset.apply_changes()

    if dataset_changeset.valid? do
      Datasets.update_submission_status(dataset_id, :published)
      {:ok, smrt_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset_for_publish)
        
      

    else
      {:noreply, assign(socket, changeset: dataset_changeset, has_validation_errors: true)}
    end
  end

  def handle_event("save-all-draft", _, socket) do
    dataset_id = socket.assigns.dataset.id

    AndiWeb.Endpoint.broadcast("form-save", "save-all", %{dataset_id: dataset_id})

    Process.sleep(1_000)

    andi_dataset = Datasets.get(dataset_id)

    dataset_changeset = InputConverter.andi_dataset_to_full_ui_changeset_for_publish(andi_dataset)
    dataset_for_publish = dataset_changeset |> Ecto.Changeset.apply_changes()

    if dataset_changeset.valid? do
      Datasets.update_submission_status(dataset_id, :published)
      {:ok, smrt_dataset} = InputConverter.andi_dataset_to_smrt_dataset(dataset_for_publish)

      

    else
      {:noreply, assign(socket, changeset: dataset_changeset, has_validation_errors: true)}
    end
  end

  def handle_info({:update_metadata_status, status}, socket) do
    form_status = socket.assigns.form_status |> Map.replace(:metadata, status)

    {:noreply, assign(socket, form_status: form_status)}
  end

  def handle_info({:update_dataset_link_status, status}, socket) do
    form_status = socket.assigns.form_status |> Map.replace(:dataset_link, status)

    {:noreply, assign(socket, form_status: form_status)}
  end

  def handle_info({:update_data_dictionary_status, status}, socket) do
    form_status = socket.assigns.form_status |> Map.replace(:data_dictionary, status)

    {:noreply, assign(socket, form_status: form_status)}
  end

  def handle_info(
        %{topic: "form-save", payload: %{form_changeset: form_changeset, dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    socket = reset_save_success(socket)
    form_changes = InputConverter.form_changes_from_changeset(form_changeset)

    {:ok, andi_dataset} = Datasets.update_from_form(socket.assigns.dataset.id, form_changes)

    new_changeset =
      andi_dataset
      |> InputConverter.andi_dataset_to_full_ui_changeset()
      |> Dataset.validate_unique_system_name()
      |> Map.put(:action, :update)

    success_message =
      case new_changeset.valid? do
        true -> "Saved successfully."
        false -> "Saved successfully. You may need to fix errors before publishing."
      end

    {:noreply,
     assign(socket,
       save_success: true,
       success_message: success_message,
       changeset: new_changeset,
       unsaved_changes: false
     )}
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  def handle_info(:cancel_edit, socket) do
    case socket.assigns.unsaved_changes do
      true -> {:noreply, assign(socket, unsaved_changes_link: "/", unsaved_changes_modal_visibility: "visible")}
      false -> {:noreply, redirect(socket, to: "/")}
    end
  end

  def handle_info(:form_update, socket) do
    {:noreply, assign(socket, unsaved_changes: true)}
  end

  def handle_info(:page_error, socket) do
    {:noreply, assign(socket, page_error: true, testing: false, save_success: false)}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    {:noreply, assign(socket, page_error: true, save_success: false)}
  end

  def handle_info(message, socket) do
    Logger.debug(inspect(message))
    {:noreply, socket}
  end

  defp reset_save_success(socket), do: assign(socket, save_success: false, has_validation_errors: false)

  defp form_valid?(form_status) do
    form_status.data_dictionary && form_status.dataset_link && form_status.metadata
  end
end
