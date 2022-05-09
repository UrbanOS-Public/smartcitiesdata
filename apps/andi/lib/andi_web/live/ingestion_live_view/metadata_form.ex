defmodule AndiWeb.IngestionLiveView.MetadataForm do
  use Phoenix.LiveView
  import Phoenix.HTML.Form

  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.InputSchemas.IngestionMetadataFormSchema
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Helpers.MetadataFormHelpers
  alias AndiWeb.IngestionLiveView.FormUpdate

  def mount(_, %{"ingestion" => ingestion}, socket) do
    changeset = IngestionMetadataFormSchema.changeset_from_andi_ingestion(ingestion)
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok, assign(socket, changeset: changeset, select_dataset_modal_visibility: "hidden")}
  end

  def render(assigns) do
    ~L"""
    <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data, id: :ingestion_metadata_form] %>
      <div class="ingestion-metadata-form__name">
        <%= label(f, :name, "Name", class: "label label--required") %>
        <%= text_input(f, :name, class: "ingestion-name input", phx_debounce: "1000") %>
        <%= ErrorHelpers.error_tag(f, :name, bind_to_input: false) %>
      </div>
      <div class="ingestion-metadata-form__format">
        <%= label(f, :sourceFormat, "Source Format", class: "label label--required") %>
        <%= select(f, :sourceFormat, MetadataFormHelpers.get_source_format_options(input_value(f, :sourceFormat)), [class: "select"]) %>
        <%= ErrorHelpers.error_tag(f, :sourceFormat, bind_to_input: false) %>
      </div>
      <button class="btn btn--manage-datasets-search" phx-click="select-dataset" type="button">Select Dataset</button>
    </form>
    """
  end

  def handle_info(
        %{topic: "form-save", event: "save-all", payload: %{ingestion_id: ingestion_id}},
        %{assigns: %{changeset: changeset}} = socket
      ) do
    original_ingestion = Ingestions.get(ingestion_id)
    {status, _} = Ingestions.update(original_ingestion, changeset.changes)
    valid? = if status == :ok, do: "valid", else: "invalid"
    FormUpdate.send_value(socket.parent_pid, {:update_save_message, valid?})
    {:noreply, socket}
  end

  def handle_event("select-dataset", _, socket) do
    {:noreply, assign(socket, select_dataset_modal_visibility: "visible")}
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> IngestionMetadataFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    FormUpdate.send_value(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset)}
  end
end
