defmodule AndiWeb.IngestionLiveView.MetadataForm do
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Helpers.MetadataFormHelpers
  alias AndiWeb.Views.DisplayNames
  alias Ecto.Changeset

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
    {_, selected_datasets} = Changeset.fetch_field(assigns.changeset, :targetDatasets)

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
          <%= if input_value(f, :sourceFormat) not in ["text/xml", "application/json", "application/geo+json"] do %>
            <%= label(f, :emptyValue, DisplayNames.get(:topLevelSelector), class: MetadataFormHelpers.top_level_selector_label_class(input_value(f, :sourceFormat))) %>
            <%= text_input(f, :emptyValue, [class: "input--text input disable-focus", readonly: true]) %>
          <% else %>
            <%= label(f, :topLevelSelector, DisplayNames.get(:topLevelSelector), class: MetadataFormHelpers.top_level_selector_label_class(input_value(f, :sourceFormat))) %>
            <%= text_input(f, :topLevelSelector, [class: "input--text input"]) %>
          <% end %>
          <%= ErrorHelpers.error_tag(f, :topLevelSelector) %>
        </div>

        <div class="ingestion-metadata-form ingestion-metadata-form__target-datasets">
          <%= label(f, :targetDatasetNames, "Dataset Names", class: "label label--required") %>
          <%= hidden_input(f, :targetDatasets, value: selected_datasets) %>
          <%= text_input(f, :targetDatasetNames, [class: "input ingestion-form-fields", value: get_dataset_names(selected_datasets), disabled: true, required: true]) %>
          <button id="open-select-dataset-modal" class="btn btn--select-dataset-search btn--primary-outline" phx-click="select-dataset" phx-target="<%= @myself %>" type="button">Select Datasets</button>
          <%= ErrorHelpers.error_tag(f, :targetDatasets, bind_to_input: false) %>
        </div>
      </form>
      <%= live_component(@socket, AndiWeb.IngestionLiveView.SelectDatasetModal,
            selected_datasets: selected_datasets,
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

  def handle_event(event, payload, socket) do
    IO.inspect("Event: #{event}, payload: #{payload}, socket: #{socket}", label: 'Unhandled Event in module #{__MODULE__}}')

    {:noreply, socket}
  end

  def handle_event(event, socket) do
    IO.inspect("Event: #{event}, socket: #{socket}", label: 'Unhandled Event in module #{__MODULE__}}')

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

  defp get_dataset_names(ids) do
    ids
    |> Enum.map(fn id ->
      case Andi.InputSchemas.Datasets.get(id) do
        nil -> "Dataset does not exist"
        dataset -> dataset.business.dataTitle
      end
    end)
    |> Enum.sort()
    |> Enum.join(", ")
  end
end
