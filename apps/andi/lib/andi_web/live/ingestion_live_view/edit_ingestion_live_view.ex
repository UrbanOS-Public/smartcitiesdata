defmodule AndiWeb.IngestionLiveView.EditIngestionLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  use AndiWeb.FooterLiveView
  require Logger

  alias Andi.InputSchemas.Ingestion
  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore
  alias Andi.Services.IngestionDelete
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.InputSchemas.IngestionMetadataFormSchema
  alias AndiWeb.InputSchemas.FinalizeFormSchema
  alias AndiWeb.InputSchemas.DataDictionaryFormSchema
  alias Ecto.Changeset

  import SmartCity.Event, only: [ingestion_update: 0]

  @instance_name Andi.instance_name()

  access_levels(render: [:private])

  def mount(
        _params,
        %{"is_curator" => is_curator, "ingestion" => ingestion, "user_id" => user_id} = _session,
        socket
      ) do
    default_changeset = Ingestion.changeset(ingestion, %{})

    {:ok,
     assign(socket,
       changeset: default_changeset,
       click_id: nil,
       delete_ingestion_modal_visibility: "hidden",
       unsaved_changes_modal_visibility: "hidden",
       is_curator: is_curator,
       unsaved_changes: false,
       page_error: false,
       # DEPRECATED
       ingestion: ingestion,
       save_success: false,
       success_message: "",
       user_id: user_id
     )}
  end

  def render(assigns) do
    ingestion =
      assigns.changeset
      |> Changeset.apply_changes()

    ingestion_changeset =
      ingestion
      |> Ingestion.changeset(%{})
      |> Ingestion.validate()

    metadata_changeset = IngestionMetadataFormSchema.extract_from_ingestion_changeset(ingestion_changeset)

    {extract_step_changesets, extract_step_errors} = Ingestion.get_extract_step_changesets_and_errors(ingestion_changeset)

    data_dictionary_changeset = DataDictionaryFormSchema.changeset_from_andi_ingestion(ingestion)

    source_format =
      case Changeset.fetch_field(ingestion_changeset, :sourceFormat) do
        {_, source_format} -> source_format
        :error -> ""
      end

    transformation_changesets = Ingestion.get_transformation_changesets(ingestion_changeset)

    finalize_changeset = FinalizeFormSchema.extract_from_ingestion_changeset(ingestion_changeset)

    ingestion_published? = assigns.ingestion.submissionStatus == :published

    ~L"""
    <%= header_render(@is_curator, AndiWeb.HeaderLiveView.header_ingestions_path()) %>
    <main aria-label="Edit Ingestion" class="edit-page" id="ingestions-edit-page">
      <div class="edit-ingestion-title">
        <h1 class="component-title-text">Define Data Ingestion</h1>
      </div>

      <div>
        <%= live_component(AndiWeb.IngestionLiveView.MetadataForm,
              id: AndiWeb.IngestionLiveView.MetadataForm.component_id(),
              changeset: metadata_changeset,
              ingestion_published?: ingestion_published?
            ) %>
      </div>

        <div>
          <div>
            <%= live_component(AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm,
                  id: AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm.component_id(),
                  extract_step_changesets: extract_step_changesets,
                  order: "1",
                  ingestion_id: ingestion_changeset.data.id,
                  ingestion_published?: ingestion_published?,
                  extract_step_errors: extract_step_errors
                ) %>
          </div>
          <div>
            <%= live_component(AndiWeb.IngestionLiveView.DataDictionaryForm,
              id: AndiWeb.IngestionLiveView.DataDictionaryForm.component_id(),
              changeset: data_dictionary_changeset,
              order: "2",
              sourceFormat: source_format,
              is_curator: @is_curator,
              ingestion_id: ingestion_changeset.data.id
              ) %>
          </div>

          <div>
            <%= live_component(AndiWeb.IngestionLiveView.Transformations.TransformationsStep,
                  id: AndiWeb.IngestionLiveView.Transformations.TransformationsStep.component_id(),
                  transformation_changesets: transformation_changesets,
                  order: "3",
                  ingestion_id: ingestion_changeset.data.id
                ) %>
          </div>

          <div>
            <%= live_component(AndiWeb.IngestionLiveView.FinalizeForm, id: :finalize_form_editor, changeset: finalize_changeset, order: "4") %>
          </div>
        </div>

      <div class="edit-page__btn-group">
      <hr>
      <div class="btn-group__standard">
        <button id="publish-button" name="publish-button" class="btn btn--primary btn--save btn--large" type="button" phx-click="publish">Publish Ingestion</button>
        <button id="save-button" name="save-button" class="btn btn--primary-outline btn--save btn--large" type="button" phx-click="save">Save Draft Ingestion</button>
          <button type="button" class="btn btn--secondary btn--large btn--cancel" phx-click="cancel-edit">Discard Changes</button>

          <button aria-label="Delete" id="ingestion-delete-button" class="btn btn--large btn--right btn--danger btn--delete" phx-click="prompt-ingestion-delete" type="button">
            <span class="delete-icon material-icons">delete</span>
            Delete
          </button>
        </div>


      </div>

      <%= live_component(@socket, AndiWeb.UnsavedChangesModal, visibility: @unsaved_changes_modal_visibility) %>
      <%= live_component(@socket, AndiWeb.ConfirmDeleteModal, type: "Ingestion", visibility: @delete_ingestion_modal_visibility, id: @ingestion.id) %>

      <div id="edit-page-snackbar" phx-hook="showSnackbar">
        <div style="display: none;"><%= @click_id %></div>
          <%= if @save_success do %>
            <p id="snackbar" class="success-message" tabindex="0"><%= @success_message %></p>
          <% end %>

          <%= if @page_error do %>
            <p id="snackbar" class="error-message" tabindex="0">A page error occurred</p>
          <% end %>
      </div>
    </main>
    <%= footer_render(@is_curator) %>
    """
  end

  def handle_info(
        {:updated_metadata, %Ecto.Changeset{data: %AndiWeb.InputSchemas.IngestionMetadataFormSchema{}} = metadata_changeset},
        socket
      ) do
    new_ingestion_changeset = Ingestion.merge_metadata_changeset(socket.assigns.changeset, metadata_changeset)

    # Needed to maintain behavior for pre-refactor data_dictionary_form
    # Remove after refactoring data_dictionary_form
    ingestion_id = socket.assigns.changeset.data.id
    {_, new_source_format} = Changeset.fetch_field(new_ingestion_changeset, :sourceFormat)

    if(new_source_format != nil) do
      AndiWeb.Endpoint.broadcast_from(self(), "source-format", "format-update", %{new_format: new_source_format, ingestion_id: ingestion_id})
    end

    {:noreply, assign(socket, changeset: new_ingestion_changeset, unsaved_changes: true)}
  end

  def handle_info({:update_all_extract_steps, extract_step_changesets}, socket) do
    new_ingestion_changeset = Ingestion.merge_extract_step_changeset(socket.assigns.changeset, extract_step_changesets)

    {:noreply, assign(socket, changeset: new_ingestion_changeset, unsaved_changes: true)}
  end

  def handle_info({:update_data_dictionary, schema_changeset}, socket) do
    new_ingestion_changeset = Ingestion.merge_data_dictionary(socket.assigns.changeset, schema_changeset)

    {:noreply, assign(socket, changeset: new_ingestion_changeset, unsaved_changes: true)}
  end

  def handle_info({:update_all_transformations, transformation_changesets}, socket) do
    new_ingestion_changeset = Ingestion.merge_transformation_changeset(socket.assigns.changeset, transformation_changesets)

    {:noreply, assign(socket, changeset: new_ingestion_changeset, unsaved_changes: true)}
  end

  def handle_info({:update_dataset, update}, socket) do
    params = %{
      targetDatasets: update
    }

    updated_changeset =
      socket.assigns.changeset
      |> Ingestion.changeset(params)

    {:noreply, assign(socket, changeset: updated_changeset)}
  end

  def handle_info(
        {:updated_finalize, %Ecto.Changeset{data: %AndiWeb.InputSchemas.FinalizeFormSchema{}} = finalize_changeset},
        socket
      ) do
    new_ingestion_changeset = Ingestion.merge_finalize_changeset(socket.assigns.changeset, finalize_changeset)

    {:noreply, assign(socket, changeset: new_ingestion_changeset, unsaved_changes: true)}
  end

  def handle_info({:update_save_message, status}, socket) do
    {:noreply, update_save_message(socket, status)}
  end

  def handle_info({:assign_editable_dictionary_field, _field_id, _index, _name, _id} = assigns, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.assign_editable_dictionary_field(assigns)

    {:noreply, socket}
  end

  def handle_info({:add_data_dictionary_field_succeeded, field_as_atomic_map, parent_bread_crumb}, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.add_data_dictionary_field_succeeded(field_as_atomic_map, parent_bread_crumb)

    {:noreply, socket}
  end

  def handle_info({:add_data_dictionary_field_cancelled}, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.add_data_dictionary_field_cancelled()

    {:noreply, socket}
  end

  def handle_info({:remove_data_dictionary_field_succeeded, deleted_field_parent_id, selected_field_id}, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.remove_data_dictionary_field_succeeded(deleted_field_parent_id, selected_field_id)

    {:noreply, socket}
  end

  def handle_info({:remove_data_dictionary_field_cancelled}, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.remove_data_dictionary_field_cancelled()

    {:noreply, socket}
  end

  def handle_info(
        %{payload: payload},
        socket
      ) do
    IO.inspect("payload: #{payload}, socket: #{socket}", label: 'Unhandled Info Message in module #{__MODULE__}}')

    {:noreply, socket}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    {:noreply, assign(socket, page_error: true, save_success: false)}
  end

  def handle_info(
        %{topic: topic, event: event, payload: payload},
        socket
      ) do
    IO.inspect("Topic: #{topic}, Event: #{event}, payload: #{payload}, socket: #{socket}",
      label: 'Unhandled Info Message in module #{__MODULE__}}'
    )

    {:noreply, socket}
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
    try do
      save_ingestion(socket)

      case publish_ingestion(ingestion_id, socket.assigns.user_id) do
        {:ok, ingestion_changeset} ->
          updated_socket = assign(socket, changeset: ingestion_changeset)
          {:noreply, update_publish_message(updated_socket, "valid")}

        _ ->
          {:noreply, update_publish_message(socket, "invalid")}
      end

    rescue
      _ ->
        {:noreply, update_publish_message(socket, "invalid")}
    end

  end

  def handle_event("save", _, socket) do
    try do
      new_ingestion_changeset = save_ingestion(socket)

      new_socket =
        assign(socket, changeset: new_ingestion_changeset)
        |> update_save_message("valid")

      {:noreply, new_socket}
    rescue
      _ -> {:noreply, socket}
    end
  end

  def handle_event("cancel-edit", _, socket) do
    case socket.assigns.unsaved_changes do
      true ->
        {:noreply,
         assign(socket,
           unsaved_changes_link: header_ingestions_path(),
           unsaved_changes_modal_visibility: "visible"
         )}

      false ->
        {:noreply, redirect(socket, to: header_ingestions_path())}
    end
  end

  def handle_event("unsaved-changes-canceled", _, socket) do
    {:noreply, assign(socket, unsaved_changes_modal_visibility: "hidden")}
  end

  def handle_event("force-cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: socket.assigns.unsaved_changes_link)}
  end

  def handle_event("file_upload_started", _, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.file_upload_start()

    {:noreply, socket}
  end

  def handle_event("file_upload", file_info, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.file_upload(file_info)

    {:noreply, socket}
  end

  def handle_event("add_data_dictionary_field", _, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.add_data_dictionary_field()

    {:noreply, socket}
  end

  def handle_event("overwrite-schema", _, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.overwrite_schema()

    {:noreply, socket}
  end

  def handle_event("overwrite-schema-cancelled", _, socket) do
    AndiWeb.IngestionLiveView.DataDictionaryForm.overwrite_schema_cancelled()

    {:noreply, socket}
  end

  def handle_event(event, payload, socket) do
    IO.inspect("Unhandled Event in module #{__MODULE__}")
    IO.inspect(event, label: "Event")
    IO.inspect(payload, label: "Payload")
    IO.inspect(socket, label: "Socket")

    {:noreply, socket}
  end

  def handle_event(event, socket) do
    IO.inspect("Event: #{event}, socket: #{socket}", label: 'Unhandled Event in module #{__MODULE__}}')

    {:noreply, socket}
  end

  defp save_ingestion(socket) do
    safe_ingestion_data =
      socket.assigns.changeset
      |> Changeset.apply_changes()

    safe_extracted_data = %{
      name: safe_ingestion_data.name,
      sourceFormat: safe_ingestion_data.sourceFormat,
      targetDatasets: safe_ingestion_data.targetDatasets,
      topLevelSelector: safe_ingestion_data.topLevelSelector,
      extractSteps: safe_ingestion_data.extractSteps,
      schema: safe_ingestion_data.schema,
      transformations: safe_ingestion_data.transformations,
      cadence: safe_ingestion_data.cadence
    }

    current_ingestion = Ingestions.get(socket.assigns.ingestion.id)

    case Ingestions.update(current_ingestion, safe_extracted_data) do
      {:ok, post_save_ingestion} ->
        post_save_ingestion
        |> Ingestion.changeset(%{})
        |> Ingestion.validate()

      {error, details} ->
        raise "Unable to save ingestion. Error: #{error}. Details: #{details}"
    end
  end

  defp save_message(true = _valid?), do: "Saved successfully."

  defp save_message(false = _valid?),
    do: "Saved successfully. You may need to fix errors before publishing."

  defp update_save_message(socket, status) do
    message = save_message(status == "valid" && socket.assigns.changeset.valid?)

    assign(socket,
      click_id: UUID.uuid4(),
      save_success: true,
      success_message: message,
      unsaved_changes: false
    )
  end

  defp publish_message(true = _valid?), do: "Published successfully."

  defp publish_message(false = _valid?),
    do: "Saved successfully, but could not publish. You may need to fix errors before publishing."

  defp update_publish_message(socket, status) do
    message = publish_message(status == "valid" && socket.assigns.changeset.valid?)

    assign(socket,
      click_id: UUID.uuid4(),
      save_success: true,
      success_message: message,
      unsaved_changes: false
    )
  end

  def publish_ingestion(ingestion_id, user_id) do
    # TODO: clean up using the socket ingestion changeset, as it is the same as below
    with andi_ingestion when not is_nil(andi_ingestion) <- Ingestions.get(ingestion_id),
         ingestion_changeset <-
           andi_ingestion
           |> Ingestion.changeset(%{})
           |> Ingestion.validate(),
         true <- ingestion_changeset.valid? do
      ingestion_for_publish = ingestion_changeset.data
      smrt_ingestion = InputConverter.andi_ingestion_to_smrt_ingestion(ingestion_for_publish)

      case Brook.Event.send(@instance_name, ingestion_update(), :andi, smrt_ingestion) do
        :ok ->
          Ingestions.update_submission_status(ingestion_id, :published)
          Andi.Schemas.AuditEvents.log_audit_event(user_id, ingestion_update(), smrt_ingestion)
          AndiWeb.Endpoint.broadcast_from(self(), "ingestion-published", "ingestion-published", %{})
          {:ok, ingestion_changeset}

        error ->
          IO.inspect("Error from brook event", label: "Publish to Brook Error")
          Logger.warn("Unable to create new SmartCity.Ingestion: #{inspect(error)}")
      end
    else
      nil ->
        IO.inspect("Ingestion not found with id: #{ingestion_id}", label: "Publishing Ingestion Error")
        {:not_found, nil}

      false ->
        andi_ingestion = Ingestions.get(ingestion_id)

        changeset_errors =
          andi_ingestion
          |> Ingestion.changeset(%{})
          |> Ingestion.validate()
          |> Map.get(:errors)

        IO.inspect("Changeset validation found errors in ingestion: #{inspect(changeset_errors)}", label: "Publishing Ingestion Error")

        {:error, changeset_errors}

      error ->
        IO.inspect(error, label: "General error when publishing ingestion")
        {:error, error}
    end
  end
end
