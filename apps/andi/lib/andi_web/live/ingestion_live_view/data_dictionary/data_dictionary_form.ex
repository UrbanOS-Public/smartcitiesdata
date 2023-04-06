defmodule AndiWeb.IngestionLiveView.DataDictionaryForm do
  @moduledoc """
  LiveComponent for editing ingestion schema
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias AndiWeb.InputSchemas.DataDictionaryFormSchema
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.DataDictionaryFields
  alias Ecto.Changeset

  def component_id() do
    :data_dictionary_form_editor
  end

  def component_step(), do: "Ingestion Schema"

  def mount(socket) do
    {
      :ok,
      assign(
        socket,
        visible?: false,
        loading_schema: false,
        schema_sample_errors: "",
        current_data_dictionary_item: :no_dictionary,
        selected_field_id: :no_dictionary,
        new_field_initial_render: false,
        add_data_dictionary_field_visible: false,
        overwrite_schema_visible?: false,
        remove_data_dictionary_field_visible: false)
    }
  end

  def render(assigns) do
    visible = if assigns.visible?, do: "expanded", else: "collapsed"
    loader_visibility = if assigns.loading_schema, do: "loading", else: "hidden"
    overwrite_visibility = if assigns.overwrite_schema_visible?, do: "visible", else: "hidden"
    validation_status = if assigns.changeset.valid?, do: "valid", else: "invalid"

    sorted_changeset = sort_data_dictionary_by_name(assigns.changeset)

    ~L"""
    <div id="data-dictionary-form" class="form-component">
      <div>
        <%= live_component(
          @socket,
          AndiWeb.FormCollapsibleHeader,
          order: @order,
          visible?: @visible?,
          validation_status: validation_status,
          step: component_step(),
          id: AndiWeb.FormCollapsibleHeader.component_id(component_step()),
          visibility_change_callback: &change_visibility/1)
        %>
      </div>
      <div class="form-section">
        <div class="component-edit-section--<%= visible %>">
        <%= f = form_for sorted_changeset, "#", [ id: "data_dictionary_form", as: :form_data, phx_change: :validate, phx_target: @myself ] %>
          <div class="data-dictionary-form-edit-section form-grid">
            <div class="upload-section">
              <%= if @sourceFormat in ["text/csv", "application/json", "text/plain"] and @is_curator do %>
                <div class="data-dictionary-form__file-upload">
                  <div class="file-input-button--<%= loader_visibility %>">
                    <div class="file-input-button">
                      <%= upload_form = form_for :form, "#", [ as: :form_data, multipart: true ] %>
                        <%= label(upload_form, :schema_sample, "Upload data sample", class: "label") %>
                        <%= file_input(upload_form, :schema_sample, phx_hook: "readFile", accept: "text/csv, application/json, text/plain, text/tab-separated-values") %>
                        <div class="data_dictionary__error-message"><%= get_schema_sample_error(@schema_sample_errors, sorted_changeset) %></div>
                      </form>
                    </div>
                  </div>
                  <button type="button" id="reader-cancel" class="file-upload-cancel-button file-upload-cancel-button--<%= loader_visibility %> btn">Cancel</button>
                  <div class="loader data-dictionary-form__loader data-dictionary-form__loader--<%= loader_visibility %>"></div>
                </div>
              <% end %>
            </div>
              <%= ErrorHelpers.error_tag(f, :schema, bind_to_input: false, class: "full-width") %>

              <div class="data-dictionary-form__tree-section">
                <div class="data-dictionary-form__tree-header data-dictionary-form-tree-header">
                  <div class="label">Enter/Edit Fields</div>
                  <div class="label label--inline">TYPE</div>
                </div>
                <div class="data-dictionary-form__tree-content data-dictionary-form-tree-content">
                  <%= live_component(AndiWeb.DataDictionary.Tree, id: :data_dictionary_tree, root_id: :data_dictionary_tree, form: f, field: :schema, selected_field_id: @selected_field_id, new_field_initial_render: @new_field_initial_render, add_field_event_name: "add_data_dictionary_field") %>
                </div>

                <div class="data-dictionary-form__tree-footer data-dictionary-form-tree-footer" >
                  <button id="data_dictionary_add-button" name="add-button" class="btn btn--primary-outline btn--save" type="button" phx-click="add_data_dictionary_field">Add</button>
                  <button id="data_dictionary_remove-button" name="remove-button" class="data-dictionary-form__remove-field-button material-icons" type="button" phx-click="remove_data_dictionary_field" phx-target="<%= @myself %>">delete_outline</button>
                </div>
              </div>

              <div class="data-dictionary-form__edit-section">
                  <%= live_component(AndiWeb.DataDictionary.FieldEditor, id: :data_dictionary_field_editor, form: @current_data_dictionary_item, source_format: @sourceFormat, dataset_or_ingestion: :ingestion) %>
              </div>
          </div>
          </form>
        </div>
      </div>

      <%= live_component(AndiWeb.DataDictionary.AddFieldEditor, id: :data_dictionary_add_field_editor, eligible_parents: DataDictionaryFields.ingestion_get_parent_ids(@changeset, @ingestion_id), visible: @add_data_dictionary_field_visible, ingestion_id: @ingestion_id, selected_field_id: @selected_field_id ) %>

      <%= live_component(AndiWeb.DataDictionary.RemoveFieldEditor, id: :data_dictionary_remove_field_editor, selected_field: @current_data_dictionary_item, visible: @remove_data_dictionary_field_visible, ingestion?: true) %>

      <%= live_component(AndiWeb.DataDictionary.OverwriteSchemaModal, id: :overwrite_schema_modal, visibility: overwrite_visibility) %>
    </div>
    """
  end

  defp sort_data_dictionary_by_name(changeset) do
    schema = case Changeset.fetch_field(changeset, :schema) do
      {_, schema} -> schema
      :error -> []
    end
    sorted_schema = Enum.sort_by(schema, &Map.get(&1, :name))

    Changeset.put_change(changeset, :schema, sorted_schema)
  end

  defp get_schema_sample_error(schema_sample_errors, changeset) do
    case schema_sample_errors do
      "" ->
        schema = case Changeset.fetch_field(changeset, :schema) do
          {_, schema} -> schema
          :error -> []
        end

        if Enum.empty?(schema) do
          "Please add a field to continue"
        else
          schema_sample_errors
        end
      _ -> schema_sample_errors
    end
  end

  defp update_current_data_dictionary_item(socket, changeset) do
    current_form = socket.assigns.current_data_dictionary_item
    case current_form do
      :no_dictionary ->
        :no_dictionary

      _ ->
        new_form_template = find_field_in_changeset(changeset, current_form.source.changes.id) |> form_for(nil, [id: :selected_schema_form])
        %{current_form | source: new_form_template.source, params: new_form_template.params}
    end

  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => target}, socket) do
    changeset = form_data
      |> DataDictionaryFormSchema.changeset_from_form_data()
    send(self(), {:update_data_dictionary, changeset})

    if Enum.any?(target, fn t -> t == "selected_modifier" end) do
      {:noreply, socket}
    else
      updated_current_form = update_current_data_dictionary_item(socket, changeset)
      {:noreply, assign(socket, current_data_dictionary_item: updated_current_form)}
    end
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    changeset = form_data
      |> DataDictionaryFormSchema.changeset_from_form_data()
    updated_current_form = update_current_data_dictionary_item(socket, changeset)

    send(self(), {:update_data_dictionary, changeset})

    {:noreply, assign(socket, current_data_dictionary_item: updated_current_form)}
  end

  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def handle_event("remove_data_dictionary_field", _, socket) do
    show_remove_field_modal? = socket.assigns.selected_field_id != :no_dictionary

    {:noreply, assign(socket, remove_data_dictionary_field_visible: show_remove_field_modal?)}
  end

  @spec assign_editable_dictionary_field({:assign_editable_dictionary_field, any, any, any, any}) ::
          any
  def assign_editable_dictionary_field({:assign_editable_dictionary_field, :no_dictionary, _, _, _}) do
    current_data_dictionary_item = DataDictionary.changeset_for_draft(%DataDictionary{}, %{}) |> form_for(nil, [id: :selected_schema_form])

    send_update(__MODULE__,
      id: component_id(),
      current_data_dictionary_item: current_data_dictionary_item,
      selected_field_id: :no_dictionary)
  end

  def assign_editable_dictionary_field({:assign_editable_dictionary_field, field_id, index, name, id}) do
    send_update(__MODULE__,
      id: component_id(),
      field_id: field_id,
      index: index,
      name: name,
      d_id: id)
  end

  def add_data_dictionary_field() do
    send_update(__MODULE__,
      id: component_id(),
      add_data_dictionary_field_visible: true)
  end

  def add_data_dictionary_field_succeeded(field_as_atomic_map, parent_bread_crumb) do
    send_update(__MODULE__,
      id: component_id(),
      action: :add_data_dictionary_field_succeeded,
      field_as_atomic_map: field_as_atomic_map,
      parent_bread_crumb: parent_bread_crumb,
      add_data_dictionary_field_visible: false)
  end

  def add_data_dictionary_field_cancelled() do
    send_update(__MODULE__,
      id: component_id(),
      add_data_dictionary_field_visible: false)
  end

  def remove_data_dictionary_field_succeeded(deleted_field_parent_id, selected_field_id) do
    send_update(__MODULE__,
      id: component_id(),
      action: :remove_data_dictionary_field,
      deleted_field_parent_id: deleted_field_parent_id,
      selected_field_id: selected_field_id)
  end

  def remove_data_dictionary_field_cancelled() do
    send_update(__MODULE__,
      id: component_id(),
      remove_data_dictionary_field_visible: false)
  end

  def overwrite_schema() do
    send_update(__MODULE__,
      id: component_id(),
      action: :overwrite_schema)
  end

  def overwrite_schema_cancelled() do
    send_update(__MODULE__,
      id: component_id(),
      action: :overwrite_schema_cancelled)
  end

  def change_visibility(updated_visibility) do
    send_update(__MODULE__,
      id: component_id(),
      visible?: updated_visibility
    )
  end

  def file_upload_start() do
    send_update(__MODULE__,
      id: component_id(),
      loading_schema: true
    )
  end

  def file_upload(%{"fileType" => file_type}) when file_type not in ["text/csv", "application/json", "application/vnd.ms-excel", "text/plain", "text/tab-separated-values"] do
    send_update(__MODULE__,
      id: component_id(),
      schema_sample_errors: "File type must be CSV, TSV, or JSON",
      loading_schema: false
    )
  end

  def file_upload(%{"fileSize" => file_size}) when file_size > 200_000_000 do
    send_update(__MODULE__,
      id: component_id(),
      schema_sample_errors: "File size must be less than 200MB",
      loading_schema: false
    )
  end

  def file_upload(%{"file" => file, "fileType" => file_type}) do
    file_type_for_upload = get_file_type_for_upload(file_type)
    send_update(__MODULE__,
      id: component_id(),
      action: :generate_new_schema,
      file: file,
      file_type: file_type_for_upload)
  end

  defp get_file_type_for_upload(file_type)
       when file_type in ["text/csv", "application/vnd.ms-excel"],
       do: "text/csv"

  defp get_file_type_for_upload(file_type), do: file_type

  def update(%{action: :generate_new_schema, file: file, file_type: "application/json"}, socket) do
    case Jason.decode(file) do
      {:error, error} ->
        {:ok, assign(socket, schema_sample_errors: "There was a problem interpreting this file: #{inspect(error.data)}")}

      {:ok, []} ->
        {:ok, assign(socket, schema_sample_errors: "Json file is empty")}
      {:ok, decoded_json} ->
        is_schema_empty? = case Changeset.fetch_field(socket.assigns.changeset, :schema) do
          {_, schema} -> schema
          :error -> []
        end
          |> Enum.empty?()

        case is_schema_empty? do
          true ->
            changeset = decoded_json
              |> List.wrap()
              |> DataDictionaryFormSchema.changeset_from_file(socket.assigns.ingestion_id)
            send(self(), {:update_data_dictionary, changeset})

            {:ok, assign(socket, loading_schema: false, current_data_dictionary_item: :no_dictionary)}
          false -> {:ok, assign(socket, loading_schema: false, pending_schema: decoded_json, overwrite_schema_visible?: true)}
        end
    end
  end

  def update(%{action: :generate_new_schema, file: file, file_type: file_type}, socket) when file_type in ["text/csv", "text/plain", "text/tab-separated-values"] do
    case validate_empty_csv(file) do
      :error ->
        {:ok, assign(socket, schema_sample_errors: "There was a problem interpreting this file")}

      {:ok, csv_file} ->
        decoded_csv = parse_sv_file(csv_file, file_type)
        is_schema_empty? = case Changeset.fetch_field(socket.assigns.changeset, :schema) do
          {_, schema} -> schema
          :error -> []
        end
          |> Enum.empty?()

        case is_schema_empty? do
            true ->
              changeset = decoded_csv
                |> List.wrap()
                |> DataDictionaryFormSchema.changeset_from_tuple_list(socket.assigns.ingestion_id)
              send(self(), {:update_data_dictionary, changeset})

              {:ok, assign(socket, loading_schema: false, current_data_dictionary_item: :no_dictionary)}
            false -> {:ok, assign(socket, loading_schema: false, pending_schema: decoded_csv, overwrite_schema_visible?: true)}
        end
    end
  end

  def update(%{field_id: field_id, index: index, name: name, d_id: id}, socket) do
    new_form = find_field_in_changeset(socket.assigns.changeset, field_id) |> form_for(nil)

    field = %{new_form | index: index, name: name, id: id}

    {:ok, assign(socket, current_data_dictionary_item: field, selected_field_id: field_id)}
  end

  def update(%{action: :overwrite_schema}, socket) do
    schema_changesets = socket.assigns.pending_schema
      |> List.wrap()
      |> DataDictionaryFormSchema.changeset_from_file(socket.assigns.ingestion_id)
    send(self(), {:update_data_dictionary, schema_changesets})

    {:ok, assign(socket, pending_schema: nil, overwrite_schema_visible?: false)}
  end

  def update(%{action: :overwrite_schema_cancelled}, socket) do
    {:ok, assign(socket, pending_schema: nil, overwrite_schema_visible?: false)}
  end

  def update(%{action: :add_data_dictionary_field_succeeded, field_as_atomic_map: field_as_atomic_map, parent_bread_crumb: parent_bread_crumb, add_data_dictionary_field_visible: add_data_dictionary_field_visible}, socket) do
    schema = case Changeset.fetch_field(socket.assigns.changeset, :schema) do
      {_, schema} -> schema
      :error -> []
    end

    updated_field = add_parent_details(field_as_atomic_map, parent_bread_crumb)
      |> Map.put(:sequence, length(schema))
      |> Map.put(:subSchema, [])

    updated_schema =
      if Enum.empty?(schema) do
        [updated_field]
      else
        Enum.reduce_while(schema, [], fn individual_schema, acc ->
          parent_id = Map.get(updated_field, :parent_id)
          schema_id = Map.get(individual_schema, :id)
          case parent_id do
            parent_id when is_nil(parent_id) -> {:halt, schema ++ [updated_field]}

            parent_id when schema_id === parent_id ->
              sub_schema = Map.get(individual_schema, :subSchema, [])
              updated_sub_schema = sub_schema ++ [updated_field]
              updated_schema = Map.put(individual_schema, :subSchema, updated_sub_schema)
              {:cont, acc ++ [updated_schema]}

            _ ->
              {:cont, acc ++ [individual_schema]}
          end
        end)
    end

    updated_data_dictionary_changeset = Changeset.put_change(socket.assigns.changeset, :schema, updated_schema)

    send(self(), {:update_data_dictionary, updated_data_dictionary_changeset})

    {:ok, assign(socket, add_data_dictionary_field_visible: add_data_dictionary_field_visible)}
  end

  def update(%{action: :remove_data_dictionary_field, deleted_field_parent_id: _deleted_field_parent_id, selected_field_id: selected_field_id}, socket) do
    schema = case Changeset.fetch_field(socket.assigns.changeset, :schema) do
      {_, schema} -> schema
      :error -> []
    end

    element_to_remove =
      Enum.find(schema, fn data_dictionary ->
        Map.get(data_dictionary, :id) == selected_field_id
      end)

    updated_schema = List.delete(schema, element_to_remove)
      |> sort_by_sequence()

    updated_data_dictionary_changeset = Changeset.put_change(socket.assigns.changeset, :schema, updated_schema)

    send(self(), {:update_data_dictionary, updated_data_dictionary_changeset})

    {:ok, assign(socket, remove_data_dictionary_field_visible: false, selected_field_id: :no_dictionary)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp add_parent_details(field, parent_bread_crumb) do
    case parent_bread_crumb do
      "Top Level" ->
        {_id, field} = Map.pop(field, :parent_id)

        Map.put(field, :bread_crumb, field.name)

      _ ->
        Map.put(field, :bread_crumb, "#{parent_bread_crumb} > #{field.name}")
    end
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

  defp handle_field_not_found(nil),
    do: DataDictionary.changeset_for_new_field(%DataDictionary{}, %{})

  defp handle_field_not_found(found_field), do: found_field

  defp sort_by_sequence(list) do
    Enum.sort_by(list, &Map.get(&1, :sequence))
  end

  defp check_file_empty(file) do
    case file == "" or file == "\n" do
      true -> :error
      _ -> {:ok, file}
    end
  end

  defp parse_sv_file(file_string, file_type) do
    regex = case file_type do
      "text/csv" -> ~r/[^[:alnum:] _,]/
      "text/plain" -> ~r/[^[:alnum:] _\t]/
    end

    file_string
    |> String.split("\n")
    |> Enum.take(2)
    |> List.update_at(0, &String.replace(&1, regex, "", global: true))
    |> Enum.map(fn row -> String.split(row, "\t") end)
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
end
