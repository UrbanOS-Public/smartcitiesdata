defmodule AndiWeb.IngestionLiveView.EditIngestionLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  use AndiWeb.FooterLiveView
  require Logger

  alias Andi.InputSchemas.Ingestions
  alias Andi.Services.IngestionStore
  alias Andi.Services.IngestionDelete
  alias Andi.InputSchemas.InputConverter
  alias AndiWeb.InputSchemas.IngestionMetadataFormSchema
  alias Ecto.Changeset

  import SmartCity.Event, only: [ingestion_update: 0]

  @instance_name Andi.instance_name()

  access_levels(render: [:private])

  def mount(
        _params,
        %{"is_curator" => is_curator, "ingestion" => ingestion, "user_id" => user_id} = _session,
        socket
      ) do
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

  def render(assigns) do
    metadata_changeset = IngestionMetadataFormSchema.extract_from_ingestion_changeset(assigns.changeset)
    ingestion_published? = assigns.ingestion.submissionStatus == :published

    ~L"""
    <%= header_render(@is_curator, AndiWeb.HeaderLiveView.header_ingestions_path()) %>
    <div class="edit-page" id="ingestions-edit-page">
        <div class="edit-ingestion-title">
          <h1 class="component-title-text">Define Data Ingestion</h1>
        </div>

      <div>
        <%= live_component(@socket, AndiWeb.IngestionLiveView.MetadataForm,
              id: :ingestion_metadata_form_editor,
              changeset: metadata_changeset,
              ingestion_published?: ingestion_published?
            ) %>
      </div>

        <div>
          <div>
            <%= live_render(@socket, AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm, id: :extract_step_form_editor, session: %{"ingestion" => @ingestion, "order" => "1"}) %>
          </div>

          <div>
            <%= live_render(@socket, AndiWeb.IngestionLiveView.DataDictionaryForm, id: :data_dictionary_form_editor, session: %{"ingestion" => @ingestion, "is_curator" => @is_curator, "order" => "2"}) %>
          </div>

          <div>
            <%= live_render(@socket, AndiWeb.IngestionLiveView.Transformations.TransformationsStep, id: :transformations_form_editor, session: %{"ingestion" => @ingestion, "order" => "3"}) %>
          </div>

          <div>
            <%= live_render(@socket, AndiWeb.IngestionLiveView.FinalizeForm, id: :finalize_form_editor, session: %{"ingestion" => @ingestion, "order" => "4"}) %>
          </div>
        </div>

      <div class="edit-page__btn-group">
      <hr>
      <div class="btn-group__standard">
        <button id="publish-button" name="publish-button" class="btn btn--primary btn--save btn--large" type="button" phx-click="publish">Publish Ingestion</button>
        <button id="save-button" name="save-button" class="btn btn--primary-outline btn--save btn--large" type="button" phx-click="save">Save Draft Ingestion</button>
          <button type="button" class="btn btn--secondary btn--large btn--cancel" phx-click="cancel-edit">Discard Changes</button>

                  <button id="ingestion-delete-button" class="btn btn--large btn--right btn--danger btn--delete" phx-click="prompt-ingestion-delete" type="button">
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
            <div id="snackbar" class="success-message"><%= @success_message %></div>
          <% end %>

          <%= if @page_error do %>
            <div id="snackbar" class="error-message">A page error occurred</div>
          <% end %>
      </div>
    </div>
    <%= footer_render(@is_curator) %>
    """
  end

  def handle_info(
        {:updated_metadata,
          %Ecto.Changeset{ data: %AndiWeb.InputSchemas.IngestionMetadataFormSchema{} } = metadata_changeset },
        socket
      ) do
    new_ingestion_changeset = Andi.InputSchemas.Ingestion.merge_metadata_changeset(socket.assigns.changeset, metadata_changeset)
    ingestion_id = Changeset.fetch_field!(new_ingestion_changeset, :id)
    new_source_format = Map.get(new_ingestion_changeset.changes, :sourceFormat, nil)


    # Needed to maintain behavior for pre-refactor data_dictionary_form
    # Remove after refactoring data_dictionary_form
    if(new_source_format != nil) do
      AndiWeb.Endpoint.broadcast_from(self(), "source-format", "format-update", %{new_format: new_source_format, ingestion_id: ingestion_id})
    end

    {:noreply, assign(socket, changeset: new_ingestion_changeset)}
  end

  def handle_info({:update_dataset, id}, socket) do
    params = %{
      targetDataset: id
    }

    updated_changeset = Andi.InputSchemas.Ingestion.changeset(socket.assigns.changeset, params)

    {:noreply, assign(socket, changeset: updated_changeset)
    }
  end

  # Remove these form_updates after all children refactor to parent/child pattern
  # Unsaved changes should be determined by comparing the current
  # ingestion from the DB to the current changeset, allowing
  # deterministic, non-stateful calculations
  def handle_info({:form_update, _}, socket) do
    {:noreply, assign(socket, unsaved_changes: true)}
  end

  def handle_info(:form_update, socket) do
    {:noreply, assign(socket, unsaved_changes: true)}
  end

  def handle_info(:test_url, socket) do
    test_url(socket)
  end

  def handle_info({:update_save_message, status}, socket) do
    {:noreply, update_save_message(socket, status)}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    {:noreply, assign(socket, page_error: true, save_success: false)}
  end

  def handle_info(
        %{topic: topic, event: event, payload: payload}, socket) do
    IO.inspect(topic, label: 'Unhandled Info Topic in module #{__MODULE__}')
    IO.inspect(event, label: 'Unhandled Info Event in module #{__MODULE__}')
    IO.inspect(payload, label: 'Unhandled Info Payload in module #{__MODULE__}')
    IO.inspect(socket, label: 'Unhandled Info Socket in module #{__MODULE__}')

    {:noreply, socket}
  end

  def handle_event(event, socket) do
    IO.inspect(event, label: 'Unhandled Event in module #{__MODULE__}')
    IO.inspect(socket, label: 'Unhandled Socket in module #{__MODULE__}')

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

    save_ingestion_safe(socket)
    AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{ingestion_id: ingestion_id})
    # Todo: Rearchitect how concurrent events are handled and remove these sleeps from draft-save and publish of datasets and ingestions
    # This sleep is needed because other save events are executing. publish_ingestion will load the ingestion from the database.
    Process.sleep(1_000)

    case publish_ingestion(ingestion_id, socket.assigns.user_id) do
      {:ok, ingestion_changeset} ->
        {:noreply, assign(socket, changeset: ingestion_changeset)}
      _ ->
        {:noreply, update_save_message(socket, "invalid")}
    end
  end



  def handle_event("save", _, socket) do
    new_ingestion = save_ingestion_safe(socket)
    {:noreply, socket} = save_ingestion(socket)
    new_socket = assign(socket, ingestion: new_ingestion)
    {:noreply, new_socket}
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

  def handle_event(event, payload, socket) do
    IO.inspect(__MODULE__, label: "Module")
    IO.inspect(event, label: 'Unhandled Event in module #{__MODULE__}')
    IO.inspect(payload, label: 'Unhandled Payload in module #{__MODULE__}')
    IO.inspect(payload, label: 'Unhandled Socket in module #{__MODULE__}')

    {:noreply, socket}
  end

  def test_url(socket) do
    save_ingestion(socket)
  end

  defp save_ingestion_safe(socket) do
    # Once all subforms are routed through this parent live view, this save function
    # can save directly to the Repo from socket.assigns.changeset without having to extract
    # the changes and reapply to the ingestion from the database, but for now, we need to treat
    # the database as the source of truth that can change at any time.

    safe_ingestion_data = socket.assigns.changeset
                          |> Changeset.apply_changes

    safe_extracted_data = %{
      name: safe_ingestion_data.name,
      sourceFormat: safe_ingestion_data.sourceFormat,
      targetDataset: safe_ingestion_data.targetDataset,
      topLevelSelector: safe_ingestion_data.topLevelSelector
    }

    current_ingestion = Ingestions.get(socket.assigns.ingestion.id)

    case Ingestions.update(current_ingestion, safe_extracted_data) do
      {:ok, post_save_ingestion} ->
        post_save_ingestion
      {error, details} ->
        raise "Unable to save ingestion. Error: #{error}. Details: #{details}"
    end


  end

  defp save_ingestion(socket) do
    ingestion_id = socket.assigns.ingestion.id

    AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{ingestion_id: ingestion_id})
    # Todo: Rearchitect how concurrent events are handled and remove these sleeps from draft-save and publish of datasets and ingestions
    # This sleep is needed because other save events are executing. publish_ingestion will load the ingestion from the database.
    Process.sleep(1_000)

    andi_ingestion = Ingestions.get(ingestion_id)
    ingestion_changeset = InputConverter.andi_ingestion_to_full_ui_changeset(andi_ingestion)
    updated_socket = assign(socket, changeset: ingestion_changeset)


    {:noreply, update_save_message(updated_socket, "valid")}
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

  def publish_ingestion(ingestion_id, user_id) do
    with andi_ingestion when not is_nil(andi_ingestion) <- Ingestions.get(ingestion_id),
         ingestion_changeset <- InputConverter.andi_ingestion_to_full_ui_changeset_for_publish(andi_ingestion),
         true <- ingestion_changeset.valid? do
      ingestion_for_publish = ingestion_changeset |> Ecto.Changeset.apply_changes()
      smrt_ingestion = InputConverter.andi_ingestion_to_smrt_ingestion(ingestion_for_publish)

      case Brook.Event.send(@instance_name, ingestion_update(), :andi, smrt_ingestion) do
        :ok ->
          Ingestions.update_submission_status(ingestion_id, :published)
          Andi.Schemas.AuditEvents.log_audit_event(user_id, ingestion_update(), smrt_ingestion)
          AndiWeb.Endpoint.broadcast_from(self(), "ingestion-published", "ingestion-published", %{})
          {:ok, ingestion_changeset}

        error ->
          Logger.warn("Unable to create new SmartCity.Ingestion: #{inspect(error)}")
      end
    else
      nil ->
        {:not_found, nil}

      false ->
        {:error, InputConverter.andi_ingestion_to_full_ui_changeset_for_publish(Ingestions.get(ingestion_id))}

      error ->
        {:error, error}
    end
  end
end
