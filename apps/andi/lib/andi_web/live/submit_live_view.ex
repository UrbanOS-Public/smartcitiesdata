defmodule AndiWeb.SubmitLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.Services.DatasetStore

  import SmartCity.Event, only: [dataset_update: 0, dataset_delete: 0]
  require Logger

  @instance_name Andi.instance_name()

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-page" id="dataset-edit-page">
      <div class="preamble">Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce vulputate fermentum felis eu consequat. Suspendisse porta ligula non urna accumsan interdum. Praesent venenatis egestas leo eget cursus. Vivamus metus ipsum, blandit eu congue ut, elementum id mi. Suspendisse quis eros non elit egestas egestas. Aenean ac ipsum nisi. Nam luctus libero ac eros mollis, ut tristique nulla convallis. Integer maximus, est quis porttitor tristique, elit libero suscipit libero, ut aliquam magna leo at ipsum. Cras a quam nec massa faucibus euismod sed et eros. Ut scelerisque lobortis dui eu vulputate. Suspendisse venenatis augue eleifend dui auctor tristique. Nulla nec mattis nisl, sed vehicula risus.</div

      <%= f = form_for @changeset, "" %>
        <% [business] = inputs_for(f, :business) %>
        <% [technical] = inputs_for(f, :technical) %>
        <%= hidden_input(f, :id) %>

        <div class="metadata-form-component">
          <%= live_render(@socket, AndiWeb.SubmitLiveView.MetadataForm, id: :metadata_form_editor, session: %{"dataset" => @dataset, "is_curator" => @is_curator}) %>
        </div>

        <div class="data-dictionary-form-component">
          <%= live_render(@socket, AndiWeb.EditLiveView.DataDictionaryForm, id: :data_dictionary_form_editor, session: %{"dataset" => @dataset, "is_curator" => @is_curator}) %>
        </div>

        <div class="url-form-component">
          <%= live_render(@socket, AndiWeb.SubmitLiveView.DatasetLink, id: :dataset_link_editor, session: %{"dataset" => @dataset}) %>
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

  def handle_info(
        %{topic: "form-save", payload: %{form_changeset: form_changeset, dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    socket = reset_save_success(socket)
    form_changes = InputConverter.form_changes_from_changeset(form_changeset)

    {:ok, andi_dataset} = Datasets.update_from_form(socket.assigns.dataset.id, form_changes)

    new_changeset =
      andi_dataset
      |> InputConverter.andi_dataset_to_full_submission_ui_changeset()
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
end
