defmodule AndiWeb.EditLiveView do
  use AndiWeb, :live_view

  alias Phoenix.HTML.Link
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.DatasetInput
  alias Andi.InputSchemas.DisplayNames
  alias Andi.InputSchemas.Options
  alias AndiWeb.EditLiveView.KeyValueEditor

  import Andi
  import SmartCity.Event, only: [dataset_update: 0]
  require Logger
  require IEx

  def render(assigns) do
    ~L"""
    <div class="edit-page">
      <%= f = form_for @changeset, "#", [phx_change: :validate, phx_submit: :save, as: :form_data] %>

      <div class="metadata-form form-section form-grid">
        <h2 class="metadata-form__top-header edit-page__box-header">Metadata</h2>
        <div class="metadata-form__title">
          <%= label(f, :title, DisplayNames.get(:dataTitle), class: "label label--required") %>
          <%= text_input(f, :dataTitle, class: "input") %>
          <%= error_tag(f, :dataTitle) %>
        </div>
        <div class="metadata-form__description">
          <%= label(f, :description, DisplayNames.get(:description), class: "label label--required") %>
          <%= textarea(f, :description, class: "input textarea") %>
          <%= error_tag(f, :description) %>
        </div>
        <div class="metadata-form__maintainer-name">
          <%= label(f, :contactName, DisplayNames.get(:contactName), class: "label label--required") %>
          <%= text_input(f, :contactName, class: "input") %>
          <%= error_tag(f, :contactName) %>
        </div>
        <div class="metadata-form__maintainer-email">
          <%= label(f, :contactEmail, DisplayNames.get(:contactEmail), class: "label label--required") %>
          <%= text_input(f, :contactEmail, class: "input") %>
          <%= error_tag(f, :contactEmail) %>
        </div>
        <div class="metadata-form__release-date">
          <%= label(f, :issuedDate, DisplayNames.get(:issuedDate), class: "label label--required") %>
          <%= date_input(f, :issuedDate, class: "input") %>
          <%= error_tag(f, :issuedDate, bind_to_input: false) %>
        </div>
        <div class="metadata-form__license">
          <%= label(f, :license, DisplayNames.get(:license), class: "label label--required") %>
          <%= text_input(f, :license, class: "input") %>
          <%= error_tag(f, :license) %>
        </div>
        <div class="metadata-form__update-frequency">
          <%= label(f, :publishFrequency, DisplayNames.get(:publishFrequency), class: "label label--required") %>
          <%= text_input(f, :publishFrequency, class: "input") %>
          <%= error_tag(f, :publishFrequency) %>
        </div>
        <div class="metadata-form__keywords">
          <%= label(f, :keywords, DisplayNames.get(:keywords), class: "label") %>
          <%= text_input(f, :keywords, value: keywords_to_string(input_value(f, :keywords)), class: "input") %>
          <div class="label label--inline">Separated by comma</div>
        </div>
        <div class="metadata-form__last-updated">
          <%= label(f, :modifiedDate, DisplayNames.get(:modifiedDate), class: "label") %>
          <%= date_input(f, :modifiedDate, class: "input") %>
        </div>
        <div class="metadata-form__spatial">
          <%= label(f, :spatial, DisplayNames.get(:spatial), class: "label") %>
          <%= text_input(f, :spatial, class: "input") %>
        </div>
        <div class="metadata-form__temporal">
          <%= label(f, :temporal, DisplayNames.get(:temporal), class: "label") %>
          <%= text_input(f, :temporal, class: "input") %>
          <%= error_tag(f, :temporal) %>
        </div>
        <div class="metadata-form__organization">
          <%= label(f, :orgTitle, DisplayNames.get(:orgTitle), class: "label label--required") %>
          <%= text_input(f, :orgTitle, [class: "input input--text", readonly: true]) %>
          <%= error_tag(f, :orgTitle) %>
        </div>
        <div class="metadata-form__language">
          <%= label(f, :language, DisplayNames.get(:language), class: "label") %>
          <%= select(f, :language, get_language_options(), value: get_language(input_value(f, :language)), class: "select") %>
        </div>
        <div class="metadata-form__homepage">
          <%= label(f, :homepage, DisplayNames.get(:homepage), class: "label") %>
          <%= text_input(f, :homepage, class: "input") %>
        </div>
        <div class="metadata-form__format">
          <%= label(f, :sourceFormat, DisplayNames.get(:sourceFormat), class: "label label--required") %>
          <%= text_input(f, :sourceFormat, [class: "input--text input", readonly: true]) %>
          <%= error_tag(f, :sourceFormat) %>
        </div>
        <div class="metadata-form__level-of-access">
          <%= label(f, :private, DisplayNames.get(:private), class: "label label--required") %>
          <%= select(f, :private, get_level_of_access_options(), class: "select") %>
          <%= error_tag(f, :private) %>
        </div>
        <div class="metadata-form__benefit-rating">
          <%= label(f, :benefitRating, DisplayNames.get(:benefitRating), class: "label label--required") %>
          <%= select(f, :benefitRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
          <%= error_tag(f, :benefitRating, bind_to_input: false) %>
        </div>
        <div class="metadata-form__risk-rating">
          <%= label(f, :riskRating, DisplayNames.get(:riskRating), class: "label label--required") %>
          <%= select(f, :riskRating, get_rating_options(), class: "select", prompt: rating_selection_prompt()) %>
          <%= error_tag(f, :riskRating, bind_to_input: false) %>
        </div>
      </div>

      <div class="url-form form-section form-grid">
        <h2 class="url-form__top-header edit-page__box-header">Configure Upload</h2>
        <div class="url-form__source-url">
          <%= label(f, :sourceUrl, DisplayNames.get(:sourceUrl), class: "label label--required") %>
          <%= text_input(f, :sourceUrl, class: "input full-width", disabled: @testing) %>
          <%= error_tag(f, :sourceUrl) %>
        </div>

        <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_query_params, css_label: "source-query-params", form: f, field: :sourceQueryParams ) %>
        <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_source_headers, css_label: "source-headers", form: f, field: :sourceHeaders ) %>

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

      <div class="edit-button-group form-grid">
        <div class="edit-button-group__cancel-btn">
          <%= Link.button("Cancel", to: "/", method: "get", class: "btn btn--large") %>
        </div>
        <div class="edit-button-group__messages">
          <%= if @save_success do %>
            <div id="success-message" class="metadata__success-message">Saved Successfully</div>
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
          <%= submit("Save", id: "save-button", class: "btn btn--save btn--large") %>
        </div>
      </div>

      </form>
    </div>
    """
  end

  def mount(%{dataset: dataset}, socket) do
    new_changeset = InputConverter.changeset_from_dataset(dataset)
    Process.flag(:trap_exit, true)

    {:ok,
     assign(socket,
       dataset: dataset,
       changeset: new_changeset,
       has_validation_errors: false,
       save_success: false,
       page_error: false,
       test_results: nil,
       testing: false
     )}
  end

  def handle_event("test_url", _, socket) do
    changes = Ecto.Changeset.apply_changes(socket.assigns.changeset)
    url = Map.get(changes, :sourceUrl) |> Andi.URI.clear_query_params()
    query_params = key_values_to_keyword_list(changes, :sourceQueryParams)
    headers = key_values_to_keyword_list(changes, :sourceHeaders)

    Task.async(fn ->
      {:test_results, Andi.Services.UrlTest.test(url, query_params: query_params, headers: headers)}
    end)

    {:noreply, assign(socket, testing: true)}
  end

  def handle_event("validate", %{"form_data" => %{"sourceUrl" => sourceUrl} = form_data, "_target" => ["form_data", "sourceUrl"]}, socket) do
    form_data
    |> InputConverter.form_changeset()
    |> DatasetInput.update_source_query_params(sourceUrl)
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> InputConverter.form_changeset()
    |> complete_validation(socket)
  end

  def handle_event("save", %{"form_data" => form_data}, socket) do
    socket = reset_save_success(socket)
    original_dataset = socket.assigns.dataset
    changeset = InputConverter.changeset_from_dataset(original_dataset, form_data)

    if changeset.valid? do
      changes = Ecto.Changeset.apply_changes(changeset)
      dataset = InputConverter.restruct(changes, original_dataset)

      case Brook.Event.send(instance_name(), dataset_update(), :andi, dataset) do
        :ok ->
          {:noreply, assign(socket, dataset: dataset, changeset: changeset, save_success: true, page_error: false)}

        error ->
          Logger.warn("Unable to create new SmartCity.Dataset: #{inspect(error)}")

          {:noreply, assign(socket, changeset: changeset)}
      end
    else
      {:noreply, assign(socket, changeset: %{changeset | action: :save}, has_validation_errors: true)}
    end
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

  def handle_info(
        {:validate,
         %{
           "form_data" => %{"sourceUrl" => source_url, "sourceQueryParams" => source_query_params} = form_data,
           "_target" => ["form_data", "sourceQueryParams" | _]
         }},
        socket
      ) do
    form_data
    |> InputConverter.form_changeset()
    |> DatasetInput.update_source_url_with_query_params(source_url, source_query_params)
    |> complete_validation(socket)
  end

  def handle_info({:validate, %{"form_data" => form_data}}, socket) do
    form_data
    |> InputConverter.form_changeset()
    |> complete_validation(socket)
  end

  def handle_info({:add_key_value, %{"field" => field}}, socket) do
    socket = reset_save_success(socket)
    changeset = DatasetInput.add_key_value(socket.assigns.changeset, SmartCity.Helpers.safe_string_to_atom(field))
    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_info({:remove_key_value, %{"id" => id, "field" => field}}, socket) do
    socket = reset_save_success(socket)
    changeset = DatasetInput.remove_key_value(socket.assigns.changeset, SmartCity.Helpers.safe_string_to_atom(field), id)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_info(message, socket) do
    Logger.debug(inspect(message))
    {:noreply, socket}
  end

  defp complete_validation(changeset, socket) do
    socket = reset_save_success(socket)

    new_changeset = Map.put(changeset, :action, :update)

    {:noreply, assign(socket, changeset: new_changeset)}
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
end
