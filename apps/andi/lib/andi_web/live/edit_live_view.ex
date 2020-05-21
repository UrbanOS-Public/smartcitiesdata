defmodule AndiWeb.EditLiveView do
  use AndiWeb, :live_view

  alias Phoenix.HTML.Link
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.DataDictionaryFields
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.DisplayNames
  alias Andi.InputSchemas.Options
  alias Andi.InputSchemas.FormTools
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.EditLiveView.DataDictionaryTree
  alias AndiWeb.EditLiveView.DataDictionaryFieldEditor
  alias Ecto.Changeset

  import Andi
  import SmartCity.Event, only: [dataset_update: 0]
  require Logger

  def render(assigns) do
    dataset_id = assigns.dataset.id

    ~L"""
      <div class="edit-page" id="dataset-edit-page">
        <%= f = form_for @changeset, "#", [phx_change: :validate, phx_submit: :save, as: :form_data] %>
        <% [business] = inputs_for(f, :business) %>
        <% [technical] = inputs_for(f, :technical) %>
        <%= hidden_input(f, :id) %>
        <%= hidden_input(business, :id) %>
        <%= hidden_input(technical, :id) %>
        <%= hidden_input(technical, :orgName) %>
        <%= hidden_input(technical, :dataName) %>
        <%= hidden_input(technical, :sourceType) %>

        <div class="metadata-form form-section form-grid">
          <h2 class="metadata-form__top-header edit-page__box-header">Metadata</h2>
          <div class="metadata-form__title">
            <%= label(business, :dataTitle, DisplayNames.get(:dataTitle), class: "label label--required") %>
            <%= text_input(business, :dataTitle, class: "input") %>
            <%= error_tag(business, :dataTitle) %>
          </div>
          <div class="metadata-form__description">
            <%= label(business, :description, DisplayNames.get(:description), class: "label label--required") %>
            <%= textarea(business, :description, class: "input textarea") %>
            <%= error_tag(business, :description) %>
          </div>
          <div class="metadata-form__maintainer-name">
            <%= label(business, :contactName, DisplayNames.get(:contactName), class: "label label--required") %>
            <%= text_input(business, :contactName, class: "input") %>
            <%= error_tag(business, :contactName) %>
          </div>
          <div class="metadata-form__maintainer-email">
            <%= label(business, :contactEmail, DisplayNames.get(:contactEmail), class: "label label--required") %>
            <%= text_input(business, :contactEmail, class: "input") %>
            <%= error_tag(business, :contactEmail) %>
          </div>
          <div class="metadata-form__release-date">
            <%= label(business, :issuedDate, DisplayNames.get(:issuedDate), class: "label label--required") %>
            <%= date_input(business, :issuedDate, class: "input", value: safe_calendar_value(input_value(business, :issuedDate))) %>
            <%= error_tag(business, :issuedDate, bind_to_input: false) %>
          </div>
          <div class="metadata-form__license">
            <%= label(business, :license, DisplayNames.get(:license), class: "label label--required") %>
            <%= text_input(business, :license, class: "input") %>
            <%= error_tag(business, :license) %>
          </div>
          <div class="metadata-form__update-frequency">
            <%= label(business, :publishFrequency, DisplayNames.get(:publishFrequency), class: "label label--required") %>
            <%= text_input(business, :publishFrequency, class: "input") %>
            <%= error_tag(business, :publishFrequency) %>
          </div>
          <div class="metadata-form__keywords">
            <%= label(business, :keywords, DisplayNames.get(:keywords), class: "label") %>
            <%= text_input(business, :keywords, value: keywords_to_string(input_value(business, :keywords)), class: "input") %>
            <div class="label label--inline">Separated by comma</div>
          </div>
          <div class="metadata-form__last-updated">
            <%= label(business, :modifiedDate, DisplayNames.get(:modifiedDate), class: "label") %>
            <%= date_input(business, :modifiedDate, class: "input", value: safe_calendar_value(input_value(business, :modifiedDate))) %>
          </div>
          <div class="metadata-form__spatial">
            <%= label(business, :spatial, DisplayNames.get(:spatial), class: "label") %>
            <%= text_input(business, :spatial, class: "input") %>
          </div>
          <div class="metadata-form__temporal">
            <%= label(business, :temporal, DisplayNames.get(:temporal), class: "label") %>
            <%= text_input(business, :temporal, class: "input") %>
            <%= error_tag(business, :temporal) %>
          </div>
          <div class="metadata-form__organization">
            <%= label(business, :orgTitle, DisplayNames.get(:orgTitle), class: "label label--required") %>
            <%= text_input(business, :orgTitle, [class: "input input--text", readonly: true]) %>
            <%= error_tag(business, :orgTitle) %>
          </div>
          <div class="metadata-form__language">
            <%= label(business, :language, DisplayNames.get(:language), class: "label") %>
            <%= select(business, :language, get_language_options(), value: get_language(input_value(business, :language)), class: "select") %>
          </div>
          <div class="metadata-form__homepage">
            <%= label(business, :homepage, DisplayNames.get(:homepage), class: "label") %>
            <%= text_input(business, :homepage, class: "input") %>
          </div>
          <div class="metadata-form__format">
            <%= label(technical, :sourceFormat, DisplayNames.get(:sourceFormat), class: "label label--required") %>
            <%= text_input(technical, :sourceFormat, [class: "input--text input", readonly: true]) %>
            <%= error_tag(technical, :sourceFormat) %>
          </div>
          <div class="metadata-form__level-of-access">
            <%= label(technical, :private, DisplayNames.get(:private), class: "label label--required") %>
            <%= select(technical, :private, get_level_of_access_options(), class: "select") %>
            <%= error_tag(technical, :private) %>
          </div>
          <div class="metadata-form__benefit-rating">
            <%= label(business, :benefitRating, DisplayNames.get(:benefitRating), class: "label label--required") %>
            <%= select(business, :benefitRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
            <%= error_tag(business, :benefitRating, bind_to_input: false) %>
          </div>
          <div class="metadata-form__risk-rating">
            <%= label(business, :riskRating, DisplayNames.get(:riskRating), class: "label label--required") %>
            <%= select(business, :riskRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
            <%= error_tag(business, :riskRating, bind_to_input: false) %>
          </div>
        </div>

        <div class="data-dictionary-form form-section form-grid">
          <h2 class="data-dictionary-form__top-header edit-page__box-header">Data Dictionary</h2>

          <div class="data-dictionary-form__tree-section">
            <div class="data-dictionary-form__tree-header data-dictionary-form-tree-header">
              <div class="label">Enter/Edit Fields</div>
              <div class="label label--inline">TYPE</div>
            </div>

            <div class="data-dictionary-form__tree-content data-dictionary-form-tree-content">
              <%= live_component(@socket, DataDictionaryTree, id: :data_dictionary_tree, root_id: :data_dictionary_tree, form: technical, field: :schema, selected_field_id: @selected_field_id, new_field_initial_render: @new_field_initial_render) %>
            </div>

            <div class="data-dictionary-form__tree-footer data-dictionary-form-tree-footer" >
              <div class="data-dictionary-form__add-field-button" phx-click="add_data_dictionary_field"></div>
              <div class="data-dictionary-form__remove-field-button" phx-click="remove_data_dictionary_field" phx-target="#dataset-edit-page"></div>
            </div>
          </div>

          <div class="data-dictionary-form__edit-section">
            <%= live_component(@socket, DataDictionaryFieldEditor, id: :data_dictionary_field_editor, form: @current_data_dictionary_item) %>
          </div>
        </div>

        <div class="url-form form-section form-grid">
          <h2 class="url-form__top-header edit-page__box-header">Configure Upload</h2>
          <div class="url-form__source-url">
            <%= label(technical, :sourceUrl, DisplayNames.get(:sourceUrl), class: "label label--required") %>
            <%= text_input(technical, :sourceUrl, class: "input full-width", disabled: @testing) %>
            <%= error_tag(technical, :sourceUrl) %>
          </div>

          <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_query_params, css_label: "source-query-params", form: technical, field: :sourceQueryParams ) %>
          <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_headers, css_label: "source-headers", form: technical, field: :sourceHeaders ) %>

          <div class="url-form__test-section">
            <button type="button" class="url-form__test-btn btn--test btn btn--large btn--action" phx-click="test_url" <%= disabled?(@testing) %>>Test</button>
            <%= if @test_results do %>
              <div class="test-status">
              Status: <span class="test-status__code <%= status_class(@test_results) %>"><%= @test_results |> Map.get(:status) %></span>
              Time: <span class="test-status__time"><%= @test_results |> Map.get(:time) %></span> ms
              </div>
            <% end %>
          </div>
        </div>

        <div class="finalize-form form-section">
          <%= live_component(@socket, AndiWeb.EditLiveView.FinalizeForm, id: :finalize_form_editor, dataset_id: dataset_id, form: technical) %>
          <%= error_tag(technical, :cadence) %>
        </div>

        <div class="edit-button-group form-grid">
          <div class="edit-button-group__cancel-btn">
            <%= Link.button("Cancel", to: "/", method: "get", class: "btn btn--large") %>
          </div>
          <div class="edit-button-group__messages">
            <%= if @save_success do %>
              <div id="success-message" class="metadata__success-message"><%= @success_message %></div>
            <% end %>
            <%= if @has_validation_errors do %>
              <div id="validation-error-message" class="metadata__error-message">There were errors with the dataset you tried to submit.</div>
            <% end %>
            <%= if @page_error do %>
              <div id="page-error-message" class="metadata__error-message">A page error occurred</div>
            <% end %>
          </div>
          <div class="edit-button-group__save-btn">
            <%= Link.button("Next", to: "/", method: "get", id: "next-button", class: "btn btn--next btn--large btn--action", disabled: true, title: "Not implemented yet.") %>
            <button type="button" id="publish-button" class="btn btn--publish btn--action btn--large" phx-click="publish">Publish</button>
            <%= submit("Save Draft", id: "save-button", name: "save-button", class: "btn btn--save btn--large", phx_value_action: "draft") %>
          </div>
        </div>
      </form>

    <%= live_component(@socket, AndiWeb.EditLiveView.DataDictionaryAddFieldEditor, id: :data_dictionary_add_field_editor, eligible_parents: get_eligible_data_dictionary_parents(@changeset), visible: @add_data_dictionary_field_visible, dataset_id: dataset_id,  selected_field_id: @selected_field_id ) %>

    <%= live_component(@socket, AndiWeb.EditLiveView.DataDictionaryRemoveFieldEditor, id: :data_dictionary_remove_field_editor, selected_field: @current_data_dictionary_item, visible: @remove_data_dictionary_field_visible) %>
    </div>
    """
  end

  def mount(_params, %{"dataset" => dataset}, socket) do
    new_changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)

    Process.flag(:trap_exit, true)

    {:ok,
     assign(socket,
       add_data_dictionary_field_visible: false,
       changeset: new_changeset,
       dataset: dataset,
       has_validation_errors: false,
       new_field_initial_render: false,
       page_error: false,
       remove_data_dictionary_field_visible: false,
       save_success: false,
       success_message: "",
       test_results: nil,
       testing: false
     )
     |> assign(get_default_dictionary_field(new_changeset))}
  end

  def handle_event("test_url", _, socket) do
    changes = Ecto.Changeset.apply_changes(socket.assigns.changeset)
    technical = Map.get(changes, :technical)
    url = Map.get(technical, :sourceUrl) |> Andi.URI.clear_query_params()
    query_params = key_values_to_keyword_list(technical, :sourceQueryParams)
    headers = key_values_to_keyword_list(technical, :sourceHeaders)

    Task.async(fn ->
      {:test_results, Andi.Services.UrlTest.test(url, query_params: query_params, headers: headers)}
    end)

    {:noreply, assign(socket, testing: true)}
  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => ["form_data", "technical", "sourceUrl"]}, socket) do
    form_data
    |> FormTools.adjust_source_query_params_for_url()
    |> InputConverter.form_data_to_ui_changeset()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => ["form_data", "technical", "sourceQueryParams" | _]}, socket) do
    form_data
    |> FormTools.adjust_source_url_for_query_params()
    |> InputConverter.form_data_to_ui_changeset()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> InputConverter.form_data_to_ui_changeset()
    |> complete_validation(socket)
  end

  def handle_event("publish", _, socket) do
    socket = reset_save_success(socket)
    changeset = socket.assigns.changeset

    if changeset.valid? do
      pending_dataset = Ecto.Changeset.apply_changes(changeset)
      {:ok, andi_dataset} = Datasets.update(pending_dataset)
      {:ok, smrt_dataset} = InputConverter.andi_dataset_to_smrt_dataset(andi_dataset)
      changeset = InputConverter.andi_dataset_to_full_ui_changeset(andi_dataset)

      case Brook.Event.send(instance_name(), dataset_update(), :andi, smrt_dataset) do
        :ok ->
          {:noreply,
           assign(socket,
             dataset: andi_dataset,
             changeset: changeset,
             save_success: true,
             success_message: "Published successfully",
             page_error: false
           )}

        error ->
          Logger.warn("Unable to create new SmartCity.Dataset: #{inspect(error)}")

          {:noreply, assign(socket, changeset: changeset)}
      end
    else
      {:noreply, assign(socket, changeset: %{changeset | action: :save}, has_validation_errors: true)}
    end
  end

  def handle_event("save", %{"form_data" => form_data}, socket) do
    changeset = form_data |> InputConverter.form_data_to_changeset_draft()
    pending_dataset = Ecto.Changeset.apply_changes(changeset)
    {:ok, _} = Datasets.update(pending_dataset)

    {_, updated_socket} =
      form_data
      |> InputConverter.form_data_to_ui_changeset()
      |> complete_validation(socket)

    success_message =
      case socket.assigns.changeset.valid? do
        true -> "Saved successfully."
        false -> "Saved successfully. You may need to fix errors before publishing."
      end

    {:noreply, assign(updated_socket, save_success: true, success_message: success_message)}
  end

  def handle_event("add", %{"field" => "sourceQueryParams"}, socket) do
    socket = reset_save_success(socket)

    pending_dataset = Ecto.Changeset.apply_changes(socket.assigns.changeset)

    {:ok, andi_dataset} = Datasets.update(pending_dataset)

    {:ok, dataset} = Datasets.add_source_query_param(andi_dataset.id)
    changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)

    {:noreply, assign(socket, changeset: changeset, dataset: dataset)}
  end

  def handle_event("add", %{"field" => "sourceHeaders"}, socket) do
    socket = reset_save_success(socket)

    pending_dataset = Ecto.Changeset.apply_changes(socket.assigns.changeset)

    {:ok, andi_dataset} = Datasets.update(pending_dataset)

    {:ok, dataset} = Datasets.add_source_header(andi_dataset.id)
    changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)

    {:noreply, assign(socket, changeset: changeset, dataset: dataset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "sourceQueryParams"}, socket) do
    socket = reset_save_success(socket)

    pending_dataset = Ecto.Changeset.apply_changes(socket.assigns.changeset)

    {:ok, andi_dataset} = Datasets.update(pending_dataset)

    {:ok, dataset} = Datasets.remove_source_query_param(andi_dataset.id, id)

    changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "sourceHeaders"}, socket) do
    socket = reset_save_success(socket)

    pending_dataset = Ecto.Changeset.apply_changes(socket.assigns.changeset)

    {:ok, andi_dataset} = Datasets.update(pending_dataset)

    {:ok, dataset} = Datasets.remove_source_header(andi_dataset.id, id)
    changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("add_data_dictionary_field", _, socket) do
    pending_dataset = Ecto.Changeset.apply_changes(socket.assigns.changeset)
    {:ok, andi_dataset} = Datasets.update(pending_dataset)
    changeset = InputConverter.andi_dataset_to_full_ui_changeset(andi_dataset)

    {:noreply, assign(socket, changeset: changeset, add_data_dictionary_field_visible: true)}
  end

  def handle_event("remove_data_dictionary_field", _, socket) do
    should_show_remove_field_modal = socket.assigns.selected_field_id != :no_dictionary

    {:noreply, assign(socket, remove_data_dictionary_field_visible: should_show_remove_field_modal)}
  end

  def handle_info({:assign_editable_dictionary_field, field_id, index, name, id}, socket) do
    new_form = find_field_in_changeset(socket.assigns.changeset, field_id) |> form_for(nil)
    field = %{new_form | index: index, name: name, id: id}

    {:noreply, assign(socket, current_data_dictionary_item: field, selected_field_id: field_id)}
  end

  def handle_info({:add_data_dictionary_field_cancelled}, socket) do
    {:noreply, assign(socket, add_data_dictionary_field_visible: false)}
  end

  def handle_info({:remove_data_dictionary_field_cancelled}, socket) do
    {:noreply, assign(socket, remove_data_dictionary_field_visible: false)}
  end

  def handle_info({:add_data_dictionary_field_succeeded, field_id}, socket) do
    dataset = Datasets.get(socket.assigns.dataset.id)
    changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)

    {:noreply,
     assign(socket,
       changeset: changeset,
       selected_field_id: field_id,
       add_data_dictionary_field_visible: false,
       new_field_initial_render: true
     )}
  end

  def handle_info({:remove_data_dictionary_field_succeeded, deleted_field_parent_id, deleted_field_index}, socket) do
    new_selected_field =
      socket.assigns.changeset
      |> get_new_selected_field(deleted_field_parent_id, deleted_field_index)

    new_selected_field_id =
      case new_selected_field do
        :no_dictionary ->
          :no_dictionary

        new_selected ->
          Changeset.fetch_field!(new_selected, :id)
      end

    dataset = Datasets.get(socket.assigns.dataset.id)
    changeset = InputConverter.andi_dataset_to_full_ui_changeset(dataset)

    {:noreply,
     assign(socket,
       changeset: changeset,
       selected_field_id: new_selected_field_id,
       new_field_initial_render: true,
       remove_data_dictionary_field_visible: false
     )}
  end

  def handle_info({:assign_crontab}, socket) do
    socket = reset_save_success(socket)

    dataset = Datasets.get(socket.assigns.dataset.id)

    changeset =
      dataset
      |> InputConverter.andi_dataset_to_full_ui_changeset()
      |> Map.put(:action, :update)

    {:noreply, assign(socket, changeset: changeset)}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    {:noreply, assign(socket, page_error: true, testing: false, save_success: false)}
  end

  def handle_info({_, {:test_results, results}}, socket) do
    {:noreply, assign(socket, test_results: results, testing: false)}
  end

  def handle_info(message, socket) do
    Logger.debug(inspect(message))
    {:noreply, socket}
  end

  defp complete_validation(changeset, socket) do
    socket = reset_save_success(socket)

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

    {:noreply, assign(socket, changeset: new_changeset, current_data_dictionary_item: updated_current_field)}
  end

  defp find_field_in_changeset(changeset, field_id) do
    changeset
    |> Changeset.fetch_change!(:technical)
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

  defp handle_field_not_found(nil), do: DataDictionary.changeset(%DataDictionary{}, %{})
  defp handle_field_not_found(found_field), do: found_field

  defp get_new_selected_field(changeset, parent_id, deleted_field_index) do
    technical_changeset = Changeset.fetch_change!(changeset, :technical)
    technical_id = Changeset.fetch_change!(technical_changeset, :id)

    if parent_id == technical_id do
      technical_changeset
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

  defp key_values_to_keyword_list(form_data, field) do
    form_data
    |> Map.get(field, [])
    |> Enum.map(fn %{key: key, value: value} -> {key, value} end)
  end

  defp reset_save_success(socket), do: assign(socket, save_success: false, has_validation_errors: false)

  defp get_language_options(), do: map_to_dropdown_options(Options.language())
  defp get_level_of_access_options, do: map_to_dropdown_options(Options.level_of_access())
  defp get_rating_options(), do: map_to_dropdown_options(Options.ratings())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  defp keywords_to_string(nil), do: ""
  defp keywords_to_string(keywords) when is_binary(keywords), do: keywords
  defp keywords_to_string(keywords), do: Enum.join(keywords, ", ")

  defp get_language(nil), do: "english"
  defp get_language(lang), do: lang

  defp rating_selection_prompt(), do: "Please Select a Value"

  defp status_class(%{status: status}) when status in 200..399, do: "test-status__code--good"
  defp status_class(%{status: _}), do: "test-status__code--bad"

  defp disabled?(true), do: "disabled"
  defp disabled?(_), do: ""

  defp get_default_dictionary_field(%{params: %{"technical" => %{schema: schema}}} = changeset) when schema != [] do
    first_data_dictionary_item =
      form_for(changeset, "#", as: :form_data)
      |> inputs_for(:technical)
      |> hd()
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

  defp get_eligible_data_dictionary_parents(changeset) do
    Ecto.Changeset.apply_changes(changeset)
    |> DataDictionaryFields.get_parent_ids()
  end

  defp safe_calendar_value(nil), do: nil

  defp safe_calendar_value(%{calendar: _, day: day, month: month, year: year}) do
    Timex.parse!("#{year}-#{month}-#{day}", "{YYYY}-{M}-{D}")
    |> NaiveDateTime.to_date()
  end

  defp safe_calendar_value(value), do: value
end
