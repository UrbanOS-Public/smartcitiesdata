defmodule AndiWeb.EditLiveView.DataDictionaryForm do
  @moduledoc """
  LiveComponent for editing dataset schema
  """
  use Phoenix.LiveView
  use AndiWeb.FormSection, schema_module: AndiWeb.InputSchemas.DataDictionaryFormSchema
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias AndiWeb.EditLiveView.DataDictionaryTree
  alias AndiWeb.InputSchemas.DataDictionaryFormSchema
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.DataDictionaryFields
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.InputConverter
  alias Ecto.Changeset

  def mount(_, %{"dataset" => dataset, "is_curator" => is_curator, "order" => order}, socket) do
    new_changeset = DataDictionaryFormSchema.changeset_from_andi_dataset(dataset)
    send(socket.parent_pid, {:update_data_dictionary_status, new_changeset.valid?})

    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")
    AndiWeb.Endpoint.subscribe("source-format")

    {:ok,
     assign(socket,
       add_data_dictionary_field_visible: false,
       remove_data_dictionary_field_visible: false,
       changeset: new_changeset,
       sourceFormat: dataset.technical.sourceFormat,
       visibility: "collapsed",
       validation_status: "collapsed",
       new_field_initial_render: false,
       dataset: dataset,
       dataset_id: dataset.id,
       technical_id: dataset.technical.id,
       overwrite_schema_visibility: "hidden",
       pending_changeset: nil,
       loading_schema: false,
       is_curator: is_curator,
       order: order
     )
     |> assign(get_default_dictionary_field(new_changeset))}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    loader_visibility =
      case assigns.loading_schema do
        true -> "loading"
        false -> "hidden"
      end

    ~L"""
    <div id="data-dictionary-form" class="form-component">
      <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="data_dictionary_form">
        <div class="section-number">
          <h3 class="component-number component-number--<%= @validation_status %>"><%= @order %></h3>
          <div class="component-number-status--<%= @validation_status %>"></div>
        </div>
        <div class="component-title full-width">
          <h2 class="component-title-text component-title-text--<%= @visibility %> ">Data Dictionary</h2>
          <div class="component-title-action">
            <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
            <div class="component-title-icon--<%= @visibility %>"></div>
          </div>
        </div>
      </div>

      <div class="form-section">
        <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data, multipart: true] %>
          <% f = Map.put(f, :errors, @changeset.errors) %>

          <div class="component-edit-section--<%= @visibility %>">

            <%= if not @is_curator do %>
              <div class="section-help">
                <a href="https://prod-os-public-data.s3-us-west-2.amazonaws.com/andi/instructions.pdf" class="document-link" target="_blank">How to Complete the Data Dictionary Section <span class="link-out"></span></a>
              </div>
            <% end %>
            <div class="data-dictionary-form-edit-section form-grid">

              <div class="upload-section">
                <%= if @sourceFormat in ["text/csv", "application/json"] and @is_curator do %>
                  <div class="data-dictionary-form__file-upload">
                    <div class="file-input-button--<%= loader_visibility %>">
                      <div class="file-input-button">
                        <%= label(f, :schema_sample, "Upload data sample", class: "label") %>
                        <%= file_input(f, :schema_sample, phx_hook: "readFile", accept: "text/csv, application/json") %>
                        <%= ErrorHelpers.error_tag(f, :schema_sample, bind_to_input: false) %>
                      </div>
                    </div>

                    <button type="button" id="reader-cancel" class="file-upload-cancel-button file-upload-cancel-button--<%= loader_visibility %> btn">Cancel</button>
                    <div class="loader data-dictionary-form__loader data-dictionary-form__loader--<%= loader_visibility %>"></div>
                  </div>
                <% end %>

                <%= ErrorHelpers.error_tag(f, :schema, bind_to_input: false, class: "full-width") %>
              </div>


              <div class="data-dictionary-form__tree-section">
                <div class="data-dictionary-form__tree-header data-dictionary-form-tree-header">
                  <div class="label">Enter/Edit Fields</div>
                  <div class="label label--inline">TYPE</div>
                </div>

                <div class="data-dictionary-form__tree-content data-dictionary-form-tree-content">
                  <%= live_component(@socket, DataDictionaryTree, id: :data_dictionary_tree, root_id: :data_dictionary_tree, form: @changeset |> form_for(nil), field: :schema, selected_field_id: @selected_field_id, new_field_initial_render: @new_field_initial_render, add_field_event_name: "add_data_dictionary_field") %>
                </div>

                <div class="data-dictionary-form__tree-footer data-dictionary-form-tree-footer" >
                  <div class="data-dictionary-form__add-field-button" phx-click="add_data_dictionary_field"></div>
                  <div class="data-dictionary-form__remove-field-button" phx-click="remove_data_dictionary_field"></div>
                </div>
              </div>

              <div class="data-dictionary-form__edit-section">
                <%= if @is_curator do %>
                  <%= live_component(@socket, AndiWeb.EditLiveView.DataDictionaryFieldEditor, id: :data_dictionary_field_editor, form: @current_data_dictionary_item, source_format: @sourceFormat) %>
                <% else %>
                  <%= live_component(@socket, AndiWeb.SubmitLiveView.DataDictionaryFieldEditor, id: :data_dictionary_field_editor, form: @current_data_dictionary_item, source_format: @sourceFormat) %>
                <% end %>
              </div>
            </div>

            <div class="edit-button-group form-grid">
              <a href="#metadata-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-expand="metadata_form">Back</a>
              <a href="#extract-step-form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-expand="extract_step_form">Next</a>
            </div>
          </div>
        </form>
      </div>

      <%= live_component(@socket, AndiWeb.EditLiveView.DataDictionaryAddFieldEditor, id: :data_dictionary_add_field_editor, eligible_parents: get_eligible_data_dictionary_parents(@dataset), visible: @add_data_dictionary_field_visible, dataset_id: @dataset.id,  selected_field_id: @selected_field_id ) %>

      <%= live_component(@socket, AndiWeb.EditLiveView.DataDictionaryRemoveFieldEditor, id: :data_dictionary_remove_field_editor, selected_field: @current_data_dictionary_item, visible: @remove_data_dictionary_field_visible) %>

      <%= live_component(@socket, AndiWeb.EditLiveView.OverwriteSchemaModal, id: :overwrite_schema_modal, visibility: @overwrite_schema_visibility) %>
    </div>
    """
  end

  def handle_event("validate", %{"data_dictionary_form_schema" => form_schema}, socket) do
    form_schema
    |> DataDictionaryFormSchema.changeset_from_form_data()
    |> send_data_dictionary_status(socket)
    |> complete_validation(socket)
  end

  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def handle_event("file_upload", %{"fileType" => file_type}, socket)
      when file_type not in ["text/csv", "application/json", "application/vnd.ms-excel"] do
    new_changeset =
      socket.assigns.changeset
      |> reset_changeset_errors()
      |> Ecto.Changeset.add_error(:schema_sample, "File type must be CSV or JSON")

    {:noreply, assign(socket, changeset: new_changeset, loading_schema: false)}
  end

  def handle_event("file_upload", %{"fileSize" => file_size}, socket) when file_size > 200_000_000 do
    new_changeset =
      socket.assigns.changeset
      |> reset_changeset_errors()
      |> Ecto.Changeset.add_error(:schema_sample, "File size must be less than 200MB")

    {:noreply, assign(socket, changeset: new_changeset, loading_schema: false)}
  end

  def handle_event("file_upload", %{"file" => file, "fileType" => file_type}, socket)
      when file_type in ["text/csv", "application/vnd.ms-excel"] do
    case validate_empty_csv(file) do
      {:ok, file} ->
        new_changeset =
          file
          |> parse_csv()
          |> DataDictionaryFormSchema.changeset_from_tuple_list(socket.assigns.dataset_id)
          |> send_data_dictionary_status(socket)

        assign_new_schema(socket, new_changeset)

      :error ->
        send_error_interpreting_file(socket.assigns.changeset, socket)
    end
  end

  def handle_event("file_upload", %{"file" => file, "fileType" => "application/json"}, socket) do
    changeset =
      socket.assigns.changeset
      |> reset_changeset_errors()

    case validate_empty_json(file) do
      {:ok, decoded_json} ->
        new_changeset =
          decoded_json
          |> List.wrap()
          |> DataDictionaryFormSchema.changeset_from_file(socket.assigns.dataset_id)
          |> send_data_dictionary_status(socket)

        assign_new_schema(socket, new_changeset)

      :error ->
        send_error_interpreting_file(changeset, socket)
    end
  end

  def handle_event("file_upload", _, socket) do
    socket.assigns.changeset
    |> send_error_interpreting_file(socket)
  end

  def handle_event("file_upload_started", _, socket) do
    {:noreply, assign(socket, loading_schema: true)}
  end

  def handle_event("file_upload_cancelled", _, socket) do
    {:noreply, assign(socket, loading_schema: false)}
  end

  def handle_event("overwrite-schema", _, %{assigns: %{pending_changeset: nil}} = socket) do
    socket.assigns.changeset
    |> send_error_interpreting_file(socket, true)
  end

  def handle_event("overwrite-schema", _, socket) do
    form_changes = InputConverter.form_changes_from_changeset(socket.assigns.pending_changeset)
    {:ok, _} = Datasets.update_from_form(socket.assigns.dataset_id, form_changes)

    {:noreply,
     assign(socket,
       changeset: socket.assigns.pending_changeset,
       pending_changeset: nil,
       overwrite_schema_visibility: "hidden"
     )
     |> assign(get_default_dictionary_field(socket.assigns.pending_changeset))}
  end

  def handle_event("overwrite-schema-cancelled", _, socket) do
    {:noreply, assign(socket, pending_changeset: nil, overwrite_schema_visibility: "hidden")}
  end

  def handle_event("add_data_dictionary_field", _, socket) do
    changes = Ecto.Changeset.apply_changes(socket.assigns.changeset) |> StructTools.to_map()
    {:ok, andi_dataset} = Datasets.update_from_form(socket.assigns.dataset.id, changes)
    changeset = DataDictionaryFormSchema.changeset_from_andi_dataset(andi_dataset) |> send_data_dictionary_status(socket)

    {:noreply, assign(socket, changeset: changeset, add_data_dictionary_field_visible: true)}
  end

  def handle_event("remove_data_dictionary_field", _, socket) do
    should_show_remove_field_modal = socket.assigns.selected_field_id != :no_dictionary

    {:noreply, assign(socket, remove_data_dictionary_field_visible: should_show_remove_field_modal)}
  end

  def handle_info(
        %{topic: "source-format", payload: %{new_format: new_format, dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    {:noreply, assign(socket, sourceFormat: new_format)}
  end

  def handle_info(%{topic: "source-format"}, socket) do
    {:noreply, socket}
  end

  def handle_info(
        %{topic: "toggle-visibility", payload: %{expand: "data_dictionary_form", dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    {:noreply, assign(socket, visibility: "expanded") |> update_validation_status()}
  end

  def handle_info(%{topic: "toggle-visibility"}, socket) do
    {:noreply, socket}
  end

  def handle_info({:add_data_dictionary_field_succeeded, field_id}, socket) do
    dataset = Datasets.get(socket.assigns.dataset.id)
    changeset = DataDictionaryFormSchema.changeset_from_andi_dataset(dataset) |> send_data_dictionary_status(socket)

    {:noreply,
     assign(socket,
       changeset: changeset,
       selected_field_id: field_id,
       add_data_dictionary_field_visible: false,
       new_field_initial_render: true
     )
     |> update_validation_status()}
  end

  def handle_info({:remove_data_dictionary_field_succeeded, deleted_field_parent_id, deleted_field_index}, socket) do
    new_selected_field =
      socket.assigns.changeset
      |> get_new_selected_field(deleted_field_parent_id, deleted_field_index, socket.assigns.technical_id)

    new_selected_field_id =
      case new_selected_field do
        :no_dictionary ->
          :no_dictionary

        new_selected ->
          Changeset.fetch_field!(new_selected, :id)
      end

    dataset = Datasets.get(socket.assigns.dataset.id)
    changeset = DataDictionaryFormSchema.changeset_from_andi_dataset(dataset) |> send_data_dictionary_status(socket)

    {:noreply,
     assign(socket,
       changeset: changeset,
       selected_field_id: new_selected_field_id,
       new_field_initial_render: true,
       remove_data_dictionary_field_visible: false
     )
     |> update_validation_status()}
  end

  def handle_info({:add_data_dictionary_field_cancelled}, socket) do
    {:noreply, assign(socket, add_data_dictionary_field_visible: false)}
  end

  def handle_info({:remove_data_dictionary_field_cancelled}, socket) do
    {:noreply, assign(socket, remove_data_dictionary_field_visible: false)}
  end

  def handle_info({:assign_editable_dictionary_field, :no_dictionary, _, _, _}, socket) do
    current_data_dictionary_item = DataDictionary.changeset_for_draft(%DataDictionary{}, %{}) |> form_for(nil)

    {:noreply, assign(socket, current_data_dictionary_item: current_data_dictionary_item, selected_field_id: :no_dictionary)}
  end

  def handle_info({:assign_editable_dictionary_field, field_id, index, name, id}, socket) do
    new_form = find_field_in_changeset(socket.assigns.changeset, field_id) |> form_for(nil)
    field = %{new_form | index: index, name: name, id: id}

    {:noreply, assign(socket, current_data_dictionary_item: field, selected_field_id: field_id)}
  end

  defp parse_csv(file_string) do
    file_string
    |> String.split("\n")
    |> Enum.take(2)
    |> List.update_at(0, &String.replace(&1, ~r/[^[:alnum:] _,]/, "", global: true))
    |> Enum.map(fn row -> String.split(row, ",") end)
    |> Enum.zip()
    |> Enum.map(fn {k, v} -> {k, convert_value(v)} end)
  end

  defp convert_value(nil), do: nil

  defp convert_value(string) do
    case Jason.decode(string) do
      {:ok, value} -> value
      {:error, _} -> string
    end
  end

  defp reset_changeset_errors(changeset) do
    Map.update!(changeset, :errors, fn errors -> Keyword.delete(errors, :schema_sample) end)
  end

  defp assign_new_schema(socket, new_changeset) do
    existing_schema_empty =
      socket.assigns.changeset
      |> reset_changeset_errors()
      |> Changeset.get_change(:schema)
      |> Enum.empty?()

    case existing_schema_empty do
      true ->
        form_changes = InputConverter.form_changes_from_changeset(new_changeset)
        {:ok, _} = Datasets.update_from_form(socket.assigns.dataset_id, form_changes)

        {:noreply, assign(socket, loading_schema: false, changeset: new_changeset) |> assign(get_default_dictionary_field(new_changeset))}

      false ->
        {:noreply, assign(socket, loading_schema: false, pending_changeset: new_changeset, overwrite_schema_visibility: "visible")}
    end
  end

  defp get_new_selected_field(changeset, parent_id, deleted_field_index, technical_id) do
    if parent_id == technical_id do
      changeset
      |> Changeset.fetch_change!(:schema)
      |> get_next_sibling(deleted_field_index)
    else
      changeset
      |> find_field_in_changeset(parent_id)
      |> Changeset.get_change(:subSchema, [])
      |> get_next_sibling(deleted_field_index)
    end
  end

  defp get_next_sibling(parent_schema, _) when length(parent_schema) <= 1, do: :no_dictionary

  defp get_next_sibling(parent_schema, deleted_field_index) when deleted_field_index == 0 do
    Enum.at(parent_schema, deleted_field_index + 1)
  end

  defp get_next_sibling(parent_schema, deleted_field_index) do
    Enum.at(parent_schema, deleted_field_index - 1)
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    current_form = socket.assigns.current_data_dictionary_item

    updated_current_field =
      case current_form do
        :no_dictionary ->
          :no_dictionary

        _ ->
          new_form_template = find_field_in_changeset(new_changeset, current_form.source.changes.id) |> form_for(nil)
          %{current_form | source: new_form_template.source, params: new_form_template.params}
      end

    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset, current_data_dictionary_item: updated_current_field) |> update_validation_status()}
  end

  defp find_field_in_changeset(changeset, field_id) do
    changeset
    |> Changeset.get_change(:schema, [])
    |> find_field_changeset_in_schema(field_id)
    |> handle_field_not_found()
  end

  defp find_field_changeset_in_schema(schema, field_id) do
    Enum.reduce_while(schema, nil, fn field, _ ->
      if Changeset.get_field(field, :id) == field_id do
        {:halt, field}
      else
        case find_field_changeset_in_schema(Changeset.get_change(field, :subSchema, []), field_id) do
          nil -> {:cont, nil}
          value -> {:halt, value}
        end
      end
    end)
  end

  defp handle_field_not_found(nil), do: DataDictionary.changeset_for_new_field(%DataDictionary{}, %{})
  defp handle_field_not_found(found_field), do: found_field

  defp get_default_dictionary_field(%{changes: %{schema: schema}} = changeset) when schema != [] do
    first_data_dictionary_item =
      form_for(changeset, "#")
      |> inputs_for(:schema)
      |> hd()

    first_selected_field_id = input_value(first_data_dictionary_item, :id)

    [
      current_data_dictionary_item: first_data_dictionary_item,
      selected_field_id: first_selected_field_id
    ]
  end

  defp get_default_dictionary_field(_changeset) do
    [
      current_data_dictionary_item: :no_dictionary,
      selected_field_id: :no_dictionary
    ]
  end

  defp get_eligible_data_dictionary_parents(dataset) do
    DataDictionaryFields.get_parent_ids(dataset)
  end

  defp validate_empty_csv(file) do
    case file == "" or file == "\n" do
      true -> :error
      _ -> {:ok, file}
    end
  end

  defp validate_empty_json(file) do
    decoded_json = Jason.decode(file)

    case decoded_json do
      {:error, _} ->
        :error

      {:ok, decoded_json_value} ->
        Enum.empty?(decoded_json_value)
        |> if(do: :error, else: {:ok, decoded_json_value})
    end
  end

  defp send_error_interpreting_file(changeset, socket, is_loading_schema \\ false) do
    new_changeset =
      changeset
      |> Map.put(:action, :update)
      |> Changeset.add_error(:schema_sample, "There was a problem interpreting this file")

    case is_loading_schema do
      true -> {:noreply, assign(socket, changeset: new_changeset)}
      _ -> {:noreply, assign(socket, changeset: new_changeset, loading_schema: false)}
    end
  end

  defp send_data_dictionary_status(changeset, socket) do
    send(socket.parent_pid, {:update_data_dictionary_status, changeset.valid?})
    changeset
  end
end
