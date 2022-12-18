defmodule AndiWeb.IngestionLiveView.MetadataForm do
  use Phoenix.LiveComponent
  use Phoenix.HTML
  import Phoenix.HTML.Form
  import Ecto.Query, only: [from: 2]


  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.InputSchemas.IngestionMetadataFormSchema
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Helpers.MetadataFormHelpers
  alias AndiWeb.IngestionLiveView.FormUpdate
  alias AndiWeb.Views.DisplayNames
  alias Ecto.Changeset

  @component_id :ingestion_metadata_form_editor

  def mount(socket) do
    IO.inspect(socket, label: "Mount #{__MODULE__}}")

    {:ok,
     assign(socket,
       select_dataset_modal_visibility: "hidden"
     )}
  end

  def render(assigns) do
    IO.inspect(assigns, label: "Render #{__MODULE__}}")
    selected_dataset = assigns.changeset.changes
      |> Map.get(:targetDataset, "")

    ~L"""
    <div>
      <%= f = form_for @changeset, "#", [ as: :form_data, phx_change: :validate, phx_target: @myself, phx_submit: :save, id: :ingestion_metadata_form ] %>

        <div class="ingestion-metadata-form ingestion-metadata-form__name">
          <%= label(f, :name, "Name", class: "label label--required") %>
          <%= text_input(f, :name, [class: "ingestion-name input ingestion-form-fields", phx_debounce: "1000", required: true]) %>
          <%= ErrorHelpers.error_tag(f, :name, bind_to_input: false) %>
        </div>

        <div class="ingestion-metadata-form ingestion-metadata-form__format">
          <%= label(f, :sourceFormat, "Source Format", class: "label label--required") %>
          <%= select(f, :sourceFormat, MetadataFormHelpers.get_source_format_options(), [class: "select ingestion-form-fields", required: true, disabled: @ingestion_published?]) %>
          <%= ErrorHelpers.error_tag(f, :sourceFormat, bind_to_input: false) %>
        </div>

        <div class="metadata-form__top-level-selector">
          <%= label(f, :topLevelSelector, DisplayNames.get(:topLevelSelector), class: MetadataFormHelpers.top_level_selector_label_class(input_value(f, :sourceFormat))) %>
          <%= if input_value(f, :sourceFormat) not in ["xml", "json", "text/xml", "application/json"] do %>
            <%= text_input(f, :emptyValue, [class: "input--text input disable-focus", readonly: true]) %>
          <% else %>
            <%= text_input(f, :topLevelSelector, [class: "input--text input"]) %>
          <% end %>
          <%= ErrorHelpers.error_tag(f, :topLevelSelector) %>
        </div>

        <div class="ingestion-metadata-form ingestion-metadata-form__target-dataset">
          <%= label(f, :targetDatasetName, "Dataset Name", class: "label label--required") %>
          <%= hidden_input(f, :targetDataset, value: selected_dataset) %>
          <%= text_input(f, :targetDatasetName, [class: "input ingestion-form-fields", value: get_dataset_name(selected_dataset), disabled: true, required: true]) %>
          <button class="btn btn--select-dataset-search btn--primary-outline" phx-click="select-dataset" phx-target="<%= @myself %>" type="button">Select Dataset</button>
          <%= ErrorHelpers.error_tag(f, :targetDataset, bind_to_input: false) %>
        </div>
      </form>
      <%= live_component(@socket, AndiWeb.IngestionLiveView.SelectDatasetModal,
            selected_dataset: selected_dataset,
            visibility: @select_dataset_modal_visibility,
            id: :ingestion_metadata_search,
            close_modal_callback: &close_modal/0
      ) %>
    </div>
    """
  end

  def handle_event("select-dataset", _, socket) do
    {:noreply,
     assign(socket,
       select_dataset_modal_visibility: "visible"
     )}
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    if(form_data["name"] == "crash") do
      0/0
    end
    send(self(), {:updated_form_data, form_data})
    {:noreply, socket}
  end

  def handle_event("cancel-dataset-search", _, socket) do
    {:noreply,
     assign(socket,
       select_dataset_modal_visibility: "hidden"
     )}
  end

  #TODO: Cleanup
  def handle_event(event, socket) do
    IO.inspect(event, label: 'Unhandled Event in module #{__MODULE__}}')
    IO.inspect(socket, label: 'Unhandled Socket in module #{__MODULE__}}')

    {:noreply, socket}
  end

  #TODO: Cleanup
  def handle_event(event, payload, socket) do
    IO.inspect(event, label: 'Unhandled Event in module #{__MODULE__}}')
    IO.inspect(payload, label: 'Unhandled Payload in module #{__MODULE__}}')
    IO.inspect(socket, label: 'Unhandled Socket in module #{__MODULE__}}')

    {:noreply, socket}
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

  def handle_info(
        %{topic: "ingestion-published"},
        socket
      ) do
    {:noreply, assign(socket, ingestion_published?: true)}
  end

#  TODO: Cleanup
  def handle_info(
        %{topic: topic, event: event, payload: payload},socket) do
    IO.inspect(topic, label: 'Unhandled Info Topic')
    IO.inspect(event, label: 'Unhandled Info Event')
    IO.inspect(payload, label: 'Unhandled Info Payload')
    IO.inspect(socket, label: 'Unhandled Info Socket')

    {:noreply, socket}
  end

  defp close_modal() do
    send_update(AndiWeb.IngestionLiveView.MetadataForm, id: @component_id, select_dataset_modal_visibility: "hidden")
  end


  defp get_dataset_name(id) when id in ["", nil], do: ""

  defp get_dataset_name(id) do
    case Andi.InputSchemas.Datasets.get(id) do
      nil -> "Dataset does not exist"
      dataset -> dataset.business.dataTitle
    end
  end
end
