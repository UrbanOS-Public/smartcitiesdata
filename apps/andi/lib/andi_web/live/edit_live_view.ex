defmodule AndiWeb.EditLiveView do
  use AndiWeb, :live_view

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.DataDictionaryFields
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.FormTools
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Datasets.Technical
  alias Andi.InputSchemas.Datasets.Business
  alias Ecto.Changeset

  alias AndiWeb.EditLiveView.FinalizeForm

  import Andi
  import SmartCity.Event, only: [dataset_update: 0]
  require Logger

  def render(assigns) do
    dataset_id = assigns.dataset.id

    ~L"""
    <div class="edit-page" id="dataset-edit-page">
      <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data, phx_hook: "Unload", data: [show_unsaved_changes_modal: @show_unsaved_changes_modal]] %>
        <% [business] = inputs_for(f, :business) %>
        <% [technical] = inputs_for(f, :technical) %>
        <%= hidden_input(f, :id) %>
        <%= hidden_input(business, :id) %>
        <%= hidden_input(business, :orgTitle) %>
        <%= hidden_input(technical, :id) %>
        <%= hidden_input(technical, :orgId) %>
        <%= hidden_input(technical, :orgName) %>
        <%= hidden_input(technical, :dataName) %>
        <%= hidden_input(technical, :systemName) %>
        <%= hidden_input(technical, :sourceType) %>
        <%= hidden_input(technical, :sourceFormat) %>


        <div class="metadata-form-component">
          <%= live_render(@socket, AndiWeb.EditLiveView.MetadataForm, id: :metadata_form_editor, session: %{"dataset" => @dataset}) %>
        </div>

        <div class="data-dictionary-form-component">
          <%= live_render(@socket, AndiWeb.EditLiveView.DataDictionaryForm, id: :data_dictionary_form_editor, session: %{"dataset" => @dataset}) %>
        </div>


        <div class="url-form-component">
          <%= live_render(@socket, AndiWeb.EditLiveView.UrlForm, id: :url_form_editor, session: %{"dataset" => @dataset}) %>
        </div>

        <div class="finalize-form-component ">
          <%= live_render(@socket, AndiWeb.EditLiveView.FinalizeForm, id: :finalize_form_editor, session: %{"dataset" => @dataset}) %>
        </div>

      </form>

      <%= live_component(@socket, AndiWeb.EditLiveView.UnsavedChangesModal, show_unsaved_changes_modal: @show_unsaved_changes_modal) %>

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

  def mount(_params, %{"dataset" => dataset}, socket) do
    new_changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)
    Process.flag(:trap_exit, true)

    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       changeset: new_changeset,
       dataset: dataset,
       has_validation_errors: false,
       new_field_initial_render: false,
       page_error: false,
       save_success: false,
       success_message: "",
       test_results: nil,
       testing: false,
       finalize_form_data: nil,
       unsaved_changes: false,
       show_unsaved_changes_modal: false
     )}
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> InputConverter.form_data_to_ui_changeset()
    |> complete_validation(socket)
    |> mark_changes()
  end

  def handle_info({:publish_succeeded, dataset: andi_dataset, changeset: changeset}, socket) do
    socket = reset_save_success(socket)

    {:noreply, assign(socket, dataset: andi_dataset, changeset: changeset, save_success: true, success_message: "Published successfully", page_error: false)}
  end

  def handle_info({:publish_failed, changeset: changeset}, socket) do
    socket = reset_save_success(socket)

    {:noreply, assign(socket, changeset: changeset, has_validation_errors: true)}
  end

  def handle_event("unsaved-changes-canceled", _, socket) do
    {:noreply, assign(socket, show_unsaved_changes_modal: false)}
  end

  def handle_event("force-cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: "/")}
  end

  def handle_info(:cancel_edit, socket) do
    case socket.assigns.unsaved_changes do
      true -> {:noreply, assign(socket, show_unsaved_changes_modal: true)}
      false -> {:noreply, redirect(socket, to: "/")}
    end
  end

  def handle_info(:form_update, socket) do
    {:noreply, assign(socket, unsaved_changes: true)}
  end

  def handle_info(%{topic: "form-save", payload: %{form_changeset: form_changeset}}, socket) do
    socket = reset_save_success(socket)
    form_changes = form_changes_from_changeset(form_changeset)

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

    {:noreply, assign(socket, save_success: true, success_message: success_message, unsaved_changes: false, changeset: new_changeset, unsaved_changes: false)}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    {:noreply, assign(socket, page_error: true, testing: false, save_success: false)}
  end

  def handle_info(message, socket) do
    Logger.debug(inspect(message))
    {:noreply, socket}
  end

  defp form_changes_from_changeset(%{changes: %{schema: schema}} = form_changeset) do
    schema_changes = Enum.map(schema, &form_changes_from_changeset/1)

    %{schema: schema_changes}
  end

  defp form_changes_from_changeset(form_changeset) do
    error_fields = Keyword.keys(form_changeset.errors)

    form_changeset
    |> Ecto.Changeset.apply_changes()
    |> StructTools.to_map
    |> add_error_fields_to_changes(error_fields)
  end

  defp add_error_fields_to_changes(changes, error_fields) do
    Enum.reduce(error_fields, changes, fn error_field, acc ->
      Map.put_new(acc, error_field, nil)
    end)
  end

  defp complete_validation(changeset, socket) do
    socket = reset_save_success(socket)
    new_changeset = Map.put(changeset, :action, :update)

    {:noreply, assign(socket, changeset: new_changeset)}
  end

  defp mark_changes({:noreply, socket}) do
    {:noreply, assign(socket, unsaved_changes: true)}
  end

  defp reset_save_success(socket), do: assign(socket, save_success: false, has_validation_errors: false)
end
