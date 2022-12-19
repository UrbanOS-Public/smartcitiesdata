defmodule AndiWeb.IngestionLiveView.MetadataForm do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form


  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Helpers.MetadataFormHelpers
  alias AndiWeb.Views.DisplayNames

  def component_id() do
    :ingestion_metadata_form_editor
  end

  def mount(socket) do
    {:ok,
     assign(socket,
       select_dataset_modal_visibility: "hidden"
     )}
  end

  def render(assigns) do
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
    metadata_form_changeset = AndiWeb.InputSchemas.IngestionMetadataFormSchema.changeset(socket.assigns.changeset, form_data)
    send(self(), {:updated_metadata, metadata_form_changeset})
    {:noreply, socket}
  end

  def handle_event("cancel-dataset-search", _, socket) do
    {:noreply,
     assign(socket,
       select_dataset_modal_visibility: "hidden"
     )}
  end

  #TODO: Cleanup
  def handle_event(event, payload, socket) do
    IO.inspect(event, label: 'Unhandled Event in module #{__MODULE__}}')
    IO.inspect(payload, label: 'Unhandled Payload in module #{__MODULE__}}')
    IO.inspect(socket, label: 'Unhandled Socket in module #{__MODULE__}}')

    {:noreply, socket}
  end

  #TODO: Cleanup
  def handle_event(event, socket) do
    IO.inspect(event, label: 'Unhandled Event in module #{__MODULE__}}')
    IO.inspect(socket, label: 'Unhandled Socket in module #{__MODULE__}}')

    {:noreply, socket}
  end

  defp close_modal() do
    send_update(AndiWeb.IngestionLiveView.MetadataForm, id: component_id(), select_dataset_modal_visibility: "hidden")
  end


  defp get_dataset_name(id) when id in ["", nil], do: ""

  defp get_dataset_name(id) do
    case Andi.InputSchemas.Datasets.get(id) do
      nil -> "Dataset does not exist"
      dataset -> dataset.business.dataTitle
    end
  end
end
