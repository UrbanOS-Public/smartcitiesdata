defmodule AndiWeb.IngestionLiveView.EditIngestionLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore
  alias Andi.Services.IngestionDelete
  alias Andi.InputSchemas.InputConverter

  import SmartCity.Event, only: [ingestion_update: 0]

  @instance_name Andi.instance_name()

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-page" id="ingestions-edit-page">
      <%= f = form_for @changeset, "" %>
        <%= hidden_input(f, :sourceFormat) %>
        <div class="edit-ingestion-title">
          <h2 class="component-title-text">Define Data Ingestion</h2>
        </div>

        <div>
          <%= live_render(@socket, AndiWeb.IngestionLiveView.MetadataForm, id: :ingestion_metadata_form_editor, session: %{"ingestion" => @ingestion}) %>
        </div>

        <div>
          <div class="extract-steps-form-component">
            <%= live_render(@socket, AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm, id: :extract_step_form_editor, session: %{"ingestion" => @ingestion, "order" => "1"}) %>
          </div>

          <div class="data-dictionary-form-component">
            <%= live_render(@socket, AndiWeb.IngestionLiveView.DataDictionaryForm, id: :data_dictionary_form_editor, session: %{"ingestion" => @ingestion, "is_curator" => @is_curator, "order" => "2"}) %>
          </div>

          <div class="transformations-form-component">
            <%= live_render(@socket, AndiWeb.IngestionLiveView.TransformationsForm, id: :transformations_form_editor, session: %{"ingestion" => @ingestion, "order" => "3"}) %>
          </div>

          <div class="finalize-form-component ">
            <%= live_render(@socket, AndiWeb.IngestionLiveView.FinalizeForm, id: :finalize_form_editor, session: %{"ingestion" => @ingestion, "order" => "4"}) %>
          </div>
        </div>
      </form>

      <div class="edit-page__btn-group">
        <div class="btn-group__standard">
          <button type="button" class="btn btn--large btn--cancel" phx-click="cancel-edit">Cancel</button>
          <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="save">Save Draft Ingestion</button>
          <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="publish">Publish Ingestion</button>
        </div>

        <hr>

        <button id="ingestion-delete-button" class="btn btn--delete" phx-click="prompt-ingestion-delete" type="button">
          <span class="delete-icon material-icons">delete_outline</span>
          DELETE
        </button>

      </div>

      <%= live_component(@socket, AndiWeb.UnsavedChangesModal, visibility: @unsaved_changes_modal_visibility) %>
      <%= live_component(@socket, AndiWeb.ConfirmDeleteModal, type: "Ingestion", visibility: @delete_ingestion_modal_visibility, id: @ingestion.id) %>

      <div id="edit-page-snackbar" phx-hook="showSnackbar">
        <div style="display: none;"><%= @click_id %></div>
          <%= if @save_success do %>
            <div id="snackbar" class="success-message"><%= @success_message %></div>
          <% end %>

          <%= if @page_error do %>
            <div id="snackbar" class="error-message">A page error occurred</div>
          <% end %>
      </div>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "ingestion" => ingestion, "user_id" => user_id} = _session, socket) do
    default_changeset = InputConverter.andi_ingestion_to_full_ui_changeset(ingestion)

    {:ok,
     assign(socket,
       changeset: default_changeset,
       click_id: nil,
       delete_ingestion_modal_visibility: "hidden",
       unsaved_changes_modal_visibility: "hidden",
       is_curator: is_curator,
       unsaved_changes: false,
       page_error: false,
       ingestion: ingestion,
       save_success: false,
       success_message: "",
       user_id: user_id
     )}
  end

  def handle_info(:form_update, socket) do
    {:noreply, assign(socket, unsaved_changes: true)}
  end

  def handle_info({:update_save_message, status}, socket) do
    message = save_message(status == "valid" && socket.assigns.changeset.valid?)

    {:noreply, assign(socket, click_id: UUID.uuid4(), save_success: true, success_message: message, unsaved_changes: false)}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    {:noreply, assign(socket, page_error: true, save_success: false)}
  end

  def handle_event("prompt-ingestion-delete", _, socket) do
    {:noreply, assign(socket, delete_ingestion_modal_visibility: "visible")}
  end

  def handle_event("delete-confirmed", _, socket) do
    ingestion_id = socket.assigns.ingestion.id
    user_id = socket.assigns.user_id

    case IngestionStore.get(ingestion_id) do
      {:ok, nil} ->
        Ingestions.delete(ingestion_id)

      {:ok, smrt_ingestion} ->
        IngestionDelete.delete(smrt_ingestion.id, user_id)
    end

    {:noreply, redirect(socket, to: header_ingestions_path())}
  end

  def handle_event("delete-canceled", _, socket) do
    {:noreply, assign(socket, delete_ingestion_modal_visibility: "hidden")}
  end

  def handle_event("publish", _, socket) do
    ingestion_id = socket.assigns.ingestion.id

    AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{ingestion_id: ingestion_id})
    Process.sleep(1_000)

    andi_ingestion = Ingestions.get(ingestion_id)
    ingestion_changeset = InputConverter.andi_ingestion_to_full_ui_changeset(andi_ingestion)

    if ingestion_changeset.valid? do
      ingestion_for_publish = ingestion_changeset |> Ecto.Changeset.apply_changes()
      smrt_ingestion = InputConverter.andi_ingestion_to_smrt_ingestion(ingestion_for_publish)

      case Brook.Event.send(@instance_name, ingestion_update(), :andi, smrt_ingestion) do
        :ok ->
          Ingestions.update_submission_status(ingestion_id, :published)
          Andi.Schemas.AuditEvents.log_audit_event(socket.assigns.user_id, ingestion_update(), smrt_ingestion)

        error ->
          Logger.warn("Unable to create new SmartCity.Ingestion: #{inspect(error)}")
      end
    end

    {:noreply, assign(socket, changeset: ingestion_changeset)}
  end

  def handle_event("save", _, socket) do
    ingestion_id = socket.assigns.ingestion.id
    AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{ingestion_id: ingestion_id})

    andi_ingestion = Ingestions.get(ingestion_id)
    ingestion_changeset = InputConverter.andi_ingestion_to_full_ui_changeset(andi_ingestion)

    {:noreply,
     assign(socket,
       changeset: ingestion_changeset,
       save_success: true,
       click_id: UUID.uuid4(),
       success_message: save_message(ingestion_changeset.valid?)
     )}
  end

  def handle_event("cancel-edit", _, socket) do
    case socket.assigns.unsaved_changes do
      true -> {:noreply, assign(socket, unsaved_changes_link: header_ingestions_path(), unsaved_changes_modal_visibility: "visible")}
      false -> {:noreply, redirect(socket, to: header_ingestions_path())}
    end
  end

  def handle_event("unsaved-changes-canceled", _, socket) do
    {:noreply, assign(socket, unsaved_changes_modal_visibility: "hidden")}
  end

  def handle_event("force-cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: socket.assigns.unsaved_changes_link)}
  end

  defp save_message(true = _valid?), do: "Saved successfully."
  defp save_message(false = _valid?), do: "Saved successfully. You may need to fix errors before publishing."
end
