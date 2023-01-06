defmodule AndiWeb.IngestionLiveView.MetadataForm do
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  import Ecto.Query, only: [from: 2]

  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.InputSchemas.Ingestions
  alias AndiWeb.InputSchemas.IngestionMetadataFormSchema
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Helpers.MetadataFormHelpers
  alias AndiWeb.IngestionLiveView.FormUpdate
  alias AndiWeb.Views.DisplayNames

  def mount(_, %{"ingestion" => ingestion}, socket) do
    changeset = IngestionMetadataFormSchema.changeset_from_andi_ingestion(ingestion)
    AndiWeb.Endpoint.subscribe("form-save")
    AndiWeb.Endpoint.subscribe("ingestion-published")
    AndiWeb.Endpoint.subscribe("source-format")
    ingestion_published? = ingestion.submissionStatus == :published

    {:ok,
     assign(socket,
       changeset: changeset,
       select_dataset_modal_visibility: "hidden",
       search_results: [],
       search_text: "",
       ingestion_published?: ingestion_published?,
       selected_dataset: ingestion.targetDataset,
       old_selected_dataset: nil,
       ingestion_id: ingestion.id
     )}
  end

  def render(assigns) do
    ~L"""
    <%= f = form_for @changeset, "#", [ as: :form_data, phx_change: :validate, id: :ingestion_metadata_form] %>
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

      <div class="ingestion-metadata-form ingestion-metadata-form__target-dataset">
        <%= label(f, :targetDatasetName, "Dataset Name", class: "label label--required") %>
        <%= hidden_input(f, :targetDataset, value: @selected_dataset) %>
        <%= text_input(f, :targetDatasetName, [class: "input ingestion-form-fields", value: get_dataset_name(@selected_dataset), disabled: true, required: true]) %>
        <button class="btn btn--select-dataset-search btn--primary-outline" phx-click="select-dataset" type="button">Select Dataset</button>
        <%= ErrorHelpers.error_tag(f, :targetDataset, bind_to_input: false) %>
      </div>

    </form>
    <%= live_component(@socket, AndiWeb.IngestionLiveView.SelectDatasetModal, visibility: @select_dataset_modal_visibility, search_results: @search_results, search_text: @search_text, selected_dataset: @selected_dataset, id: :ingestion_metadata_search) %>

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

  def handle_info(
        %{topic: "ingestion-published"},
        socket
      ) do
    {:noreply, assign(socket, ingestion_published?: true)}
  end

  def handle_event("select-dataset", _, socket) do
    {:noreply,
     assign(socket,
       select_dataset_modal_visibility: "visible",
       old_selected_dataset: socket.assigns.selected_dataset
     )}
  end

  def handle_event("select-dataset-search", %{"id" => id}, socket) do
    if(socket.assigns.selected_dataset == id) do
      {:noreply, assign(socket, selected_dataset: nil, old_selected_dataset: id)}
    else
      {:noreply, assign(socket, selected_dataset: id, old_selected_dataset: socket.assigns.selected_dataset)}
    end
  end

  def handle_event("remove-selected-dataset", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_dataset: nil, old_selected_dataset: id)}
  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => ["form_data", "sourceFormat"]}, socket) do
    AndiWeb.Endpoint.broadcast_from(self(), "source-format", "format-update", %{
      new_format: form_data["sourceFormat"],
      ingestion_id: socket.assigns.ingestion_id
    })

    form_data
    |> IngestionMetadataFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> IngestionMetadataFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("save-dataset-search", %{"id" => id}, socket) do
    form_data = socket.assigns.changeset.changes

    updated_form_data =
      Map.put(form_data, :targetDataset, id)
      |> Map.new(fn {key, value} -> {Atom.to_string(key), value} end)

    changeset =
      socket.assigns.changeset.changes
      |> Map.put(:targetDataset, id)
      |> IngestionMetadataFormSchema.changeset_from_form_data()

    handle_event("validate", %{"form_data" => updated_form_data}, socket)

    {:noreply,
     assign(socket,
       select_dataset_modal_visibility: "hidden",
       search_results: [],
       selected_dataset: id,
       changeset: changeset,
       old_selected_dataset: nil
     )}
  end

  def handle_event("cancel-dataset-search", _, socket) do
    {:noreply,
     assign(socket,
       select_dataset_modal_visibility: "hidden",
       selected_dataset: if(socket.assigns.old_selected_dataset, do: socket.assigns.old_selected_dataset, else: nil),
       search_results: [],
       old_selected_dataset: nil
     )}
  end

  def handle_event("datasets-search", %{"search-value" => search_value}, socket) do
    search_results = query_on_dataset_search_change(search_value, socket)

    {:noreply,
     assign(socket,
       manage_datasets_modal_visibility: "visible",
       search_results: search_results,
       selected_dataset: socket.assigns.selected_dataset
     )}
  end

  defp query_on_dataset_search_change(search_value, %{assigns: %{search_text: search_value, search_results: search_results}}) do
    search_results
  end

  defp query_on_dataset_search_change(search_value, _) do
    refresh_dataset_search_results(search_value)
  end

  defp refresh_dataset_search_results(search_value) do
    like_search_string = "%#{search_value}%"

    query =
      from(dataset in Dataset,
        join: technical in assoc(dataset, :technical),
        join: business in assoc(dataset, :business),
        preload: [business: business, technical: technical],
        where: not is_nil(technical.id),
        where: not is_nil(business.id),
        where: ilike(business.dataTitle, type(^like_search_string, :string)),
        or_where: ilike(business.orgTitle, type(^like_search_string, :string)),
        or_where: ^search_value in business.keywords,
        select: dataset
      )

    query
    |> Andi.Repo.all()
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    FormUpdate.send_value(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset)}
  end

  defp get_dataset_name(id) when id in ["", nil], do: ""

  defp get_dataset_name(id) do
    case Andi.InputSchemas.Datasets.get(id) do
      nil -> "Dataset does not exist"
      dataset -> dataset.business.dataTitle
    end
  end
end
