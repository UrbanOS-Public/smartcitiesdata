defmodule AndiWeb.EditLiveView.ExtractStepForm do
  @moduledoc """
  LiveComponent for editing dataset URL
  """
  use Phoenix.LiveView
  use AndiWeb.FormSection, schema_module: AndiWeb.InputSchemas.ExtractStep
  import Phoenix.HTML
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames

  def mount(_, %{"dataset" => dataset}, socket) do
    new_changeset =
      dataset
      |> Andi.InputSchemas.StructTools.to_map()
      |> ExtractHttpStep.changeset()

    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       changeset: new_changeset,
       testing: false,
       test_results: nil,
       visibility: "collapsed",
       validation_status: "collapsed",
       dataset_id: dataset.id
     )}
  end

  def render(assigns) do
    action =
      case assigns.visibility do
        "collapsed" -> "EDIT"
        "expanded" -> "MINIMIZE"
      end

    ~L"""
      <div id="extract-step-form" class="form-component">
        <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="extract_form">
          <div class="section-number">
            <h3 class="component-number component-number--<%= @validation_status %>">3</h3>
            <div class="component-number-status--<%= @validation_status %>"></div>
          </div>
          <div class="component-title full-width">
            <h2 class="component-title-text component-title-text--<%= @visibility %> ">Configure Ingest Steps</h2>
            <div class="component-title-action">
              <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
              <div class="component-title-icon--<%= @visibility %>"></div>
            </div>
          </div>
        </div>

        <div class="form-section">
          <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data] %>
            <div class="component-edit-section--<%= @visibility %>">
              <div class="extract-step-form-edit-section form-grid">
                <div class="extract-step-form__type">
                  <%= label(f, :type, DisplayNames.get(:type), class: "label label--required") %>
                  <%= select(f, :type, get_http_methods(), id: "step_type", class: "extract-step-form__type select") %>
                  <%= ErrorHelpers.error_tag(f, :type) %>
                </div>
                <div class="extract-step-form__url">
                  <%= label(f, :url, DisplayNames.get(:url), class: "label label--required") %>
                  <%= text_input(f, :url, class: "input", phx_blur: "validate_url") %>
                  <%= ErrorHelpers.error_tag(f, :url, bind_to_input: false) %>
                </div>

                <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_queryParams, css_label: "source-query-params", form: f, field: :queryParams ) %>
                <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_headers, css_label: "source-headers", form: f, field: :headers ) %>

                <div class="extract_step__test-section">
                  <button type="button" class="extract_step__test-btn btn--test btn btn--large btn--action" phx-click="test_url" <%= disabled?(@testing) %>>Test</button>
                  <%= if @test_results do %>
                    <div class="test-status">
                    Status: <span class="test-status__code <%= status_class(@test_results) %>"><%= @test_results |> Map.get(:status) |> HttpStatusDescriptions.simple() %></span>
                    <%= status_tooltip(@test_results) %>
                    Time: <span class="test-status__time"><%= @test_results |> Map.get(:time) %></span> ms
                    </div>
                  <% end %>
                </div>
              </div>

              <div class="edit-button-group form-grid">
                <div class="edit-button-group__cancel-btn">
                  <a href="#data-dictionary-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-expand="data_dictionary_form">Back</a>
                  <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
                </div>

                <div class="edit-button-group__save-btn">
                  <a href="#finalize_form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-expand="finalize_form">Next</a>
                  <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="save">Save Draft</button>
                </div>
                </div>
            </div>
          </form>
        </div>
      </div>
    """
  end

  def handle_event("test_url", _, socket) do
    changes = Ecto.Changeset.apply_changes(socket.assigns.changeset)
    url = Map.get(changes, :url) |> Andi.URI.clear_query_params()
    query_params = key_values_to_keyword_list(changes, :queryParams)
    headers = key_values_to_keyword_list(changes, :headers)

    Task.async(fn ->
      {:test_results, Andi.Services.UrlTest.test(url, query_params: query_params, headers: headers)}
    end)

    {:noreply, assign(socket, testing: true)}
  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => ["form_data", "url"]}, socket) do
    form_data
    |> FormTools.adjust_source_query_params_for_url()
    # TODO maybe refactor
    |> UrlFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => ["form_data", "queryParams" | _]}, socket) do
    form_data
    |> FormTools.adjust_source_url_for_query_params()
    # TODO maybe refactor
    |> UrlFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> UrlFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def handle_event("add", %{"field" => "queryParams"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()

    Datasets.update_from_form(socket.assigns.dataset_id, current_changes)

    {:ok, dataset} = Datasets.add_source_query_param(socket.assigns.dataset_id)
    changeset = UrlFormSchema.changeset_from_andi_dataset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("add", %{"field" => "headers"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()

    Datasets.update_from_form(socket.assigns.dataset_id, current_changes)

    {:ok, dataset} = Datasets.add_source_header(socket.assigns.dataset_id)
    changeset = UrlFormSchema.changeset_from_andi_dataset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "queryParams"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()

    Datasets.update_from_form(socket.assigns.dataset_id, current_changes)

    {:ok, dataset} = Datasets.remove_source_query_param(socket.assigns.dataset_id, id)
    changeset = UrlFormSchema.changeset_from_andi_dataset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "headers"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()

    Datasets.update_from_form(socket.assigns.dataset_id, current_changes)

    {:ok, dataset} = Datasets.remove_source_header(socket.assigns.dataset_id, id)
    changeset = UrlFormSchema.changeset_from_andi_dataset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_info(
        %{topic: "toggle-visibility", payload: %{expand: "extract_step_form", dataset_id: dataset_id}},
        %{assigns: %{dataset_id: dataset_id}} = socket
      ) do
    {:noreply, assign(socket, visibility: "expanded") |> update_validation_status()}
  end

  def handle_info(%{topic: "toggle-visibility"}, socket) do
    {:noreply, socket}
  end

  def handle_info({_, {:test_results, results}}, socket) do
    send(socket.parent_pid, {:test_results, results})
    {:noreply, assign(socket, test_results: results, testing: false)}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    send(socket.parent_pid, :page_error)
    {:noreply, assign(socket, page_error: true, testing: false, save_success: false)}
  end

  def handle_info(message, socket) do
    Logger.debug(inspect(message))
    {:noreply, socket}
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset) |> update_validation_status()}
  end

  defp disabled?(true), do: "disabled"
  defp disabled?(_), do: ""

  defp status_class(%{status: status}) when status in 200..399, do: "test-status__code--good"
  defp status_class(%{status: _}), do: "test-status__code--bad"
  defp status_tooltip(%{status: status}) when status in 200..399, do: status_tooltip(%{status: status}, "shown")

  defp status_tooltip(%{status: status}, modifier \\ "shown") do
    assigns = %{
      description: HttpStatusDescriptions.get(status),
      modifier: modifier
    }

    ~E(<sup class="test-status__tooltip-wrapper"><i phx-hook="addTooltip" data-tooltip-content="<%= @description %>" class="material-icons-outlined test-status__tooltip--<%= @modifier %>">info</i></sup>)
  end

  defp key_values_to_keyword_list(form_data, field) do
    form_data
    |> Map.get(field, [])
    |> Enum.map(fn %{key: key, value: value} -> {key, value} end)
  end

  defp get_http_methods(), do: map_to_dropdown_options(Options.http_method())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end
end
