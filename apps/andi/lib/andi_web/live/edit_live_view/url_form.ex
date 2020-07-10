defmodule AndiWeb.EditLiveView.UrlForm do
  @moduledoc """
  LiveComponent for editing dataset URL
  """
  use Phoenix.LiveView
  import Phoenix.HTML.Form
  require Logger

  alias AndiWeb.ErrorHelpers
  alias Andi.InputSchemas.DisplayNames
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.InputSchemas.UrlFormSchema
  alias Andi.InputSchemas.FormTools
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.Datasets

  def mount(_, %{"dataset" => dataset}, socket) do
    new_changeset = UrlFormSchema.changeset_from_andi_dataset(dataset)

    {:ok,
     assign(socket,
       changeset: new_changeset,
       testing: false,
       test_results: nil,
       visibility: "collapsed",
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
      <div id="url-form" class="form-component">
        <div class="component-header" phx-click="toggle-component-visibility" phx-value-component="url_form">
          <h3 class="component-number component-number--<%= @visibility %>">3</h3>
          <div class="component-title full-width">
            <h2 class="component-title-text component-title-text--<%= @visibility %> ">Configure Upload</h2>
            <div class="component-title-action">
              <div class="component-title-action-text--<%= @visibility %>"><%= action %></div>
              <div class="component-title-icon--<%= @visibility %>"></div>
            </div>
          </div>
        </div>

        <div class="form-section">
          <%= f = form_for @changeset, "#", [phx_change: :cam, as: :form_data] %>
            <div class="component-edit-section--<%= @visibility %>">
              <div class="url-form-edit-section form-grid">
                <div class="url-form__source-url">
                  <%= label(f, :sourceUrl, DisplayNames.get(:sourceUrl), class: "label label--required") %>
                  <%= text_input(f, :sourceUrl, class: "input full-width", disabled: @testing) %>
                  <%= ErrorHelpers.error_tag(f, :sourceUrl) %>
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
                  <a href="#data-dictionary-form" id="back-button" class="btn btn--back btn--large" phx-click="toggle-component-visibility" phx-value-component-collapse="url_form" phx-value-component-expand="data_dictionary_form">Back</a>
                  <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
                </div>

                <div class="edit-button-group__save-btn">
                  <a href="#finalize_form" id="next-button" class="btn btn--next btn--large btn--action" phx-click="toggle-component-visibility" phx-value-component-collapse="url_form" phx-value-component-expand="finalize_form">Next</a>
                  <button id="save-button" name="save-button" class="btn btn--save btn--large" type="button" phx-click="camsave">Save Draft</button>
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
    url = Map.get(changes, :sourceUrl) |> Andi.URI.clear_query_params()
    query_params = key_values_to_keyword_list(changes, :sourceQueryParams)
    headers = key_values_to_keyword_list(changes, :sourceHeaders)

    Task.async(fn ->
      {:test_results, Andi.Services.UrlTest.test(url, query_params: query_params, headers: headers)}
    end)

    {:noreply, assign(socket, testing: true)}
  end

  def handle_event("cam", %{"form_data" => form_data, "_target" => ["form_data", "sourceUrl"]}, socket) do
    form_data
    |> FormTools.adjust_source_query_params_for_url()
    |> UrlFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
    |> mark_changes()
  end

  def handle_event("cam", %{"form_data" => form_data, "_target" => ["form_data", "sourceQueryParams" | _]}, socket) do
    form_data
    |> FormTools.adjust_source_url_for_query_params()
    |> UrlFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
    |> mark_changes()
  end

  def handle_event("cam", %{"form_data" => form_data}, socket) do
    form_data
    |> UrlFormSchema.changeset_from_form_data()
    |> complete_validation(socket)
    |> mark_changes()
  end

  def handle_event("camsave", _, socket) do
    changeset =
      socket.assigns.changeset
      |> Map.put(:action, :update)

    changes = Ecto.Changeset.apply_changes(changeset) |> StructTools.to_map

    send(socket.parent_pid, {:form_save, changes})

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("add", %{"field" => "sourceQueryParams"} = message, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes
      |> StructTools.to_map

    Datasets.update_from_form(socket.assigns.dataset_id, current_changes)

    {:ok, dataset} = Datasets.add_source_query_param(socket.assigns.dataset_id)
    changeset = UrlFormSchema.changeset_from_andi_dataset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("add", %{"field" => "sourceHeaders"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes
      |> StructTools.to_map

    Datasets.update_from_form(socket.assigns.dataset_id, current_changes)

    {:ok, dataset} = Datasets.add_source_header(socket.assigns.dataset_id)
    changeset = UrlFormSchema.changeset_from_andi_dataset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "sourceQueryParams"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes
      |> StructTools.to_map

    Datasets.update_from_form(socket.assigns.dataset_id, current_changes)

    {:ok, dataset} = Datasets.remove_source_query_param(socket.assigns.dataset_id, id)
    changeset = UrlFormSchema.changeset_from_andi_dataset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "sourceHeaders"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes
      |> StructTools.to_map

    Datasets.update_from_form(socket.assigns.dataset_id, current_changes)

    {:ok, dataset} = Datasets.remove_source_header(socket.assigns.dataset_id, id)
    changeset = UrlFormSchema.changeset_from_andi_dataset(dataset)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("toggle-component-visibility", %{"component" => component}, socket) do
    new_visibility = case Map.get(socket.assigns, :visibility) do
                       "expanded" -> "collapsed"
                       "collapsed" -> "expanded"
                     end

    {:noreply, assign(socket, visibility: new_visibility)}
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
    new_changeset = Map.put(changeset, :action, :update)

    {:noreply, assign(socket, changeset: new_changeset)}
  end

  defp mark_changes({:noreply, socket}) do
    {:noreply, assign(socket, unsaved_changes: true)}
  end

  defp disabled?(true), do: "disabled"
  defp disabled?(_), do: ""

  defp status_class(%{status: status}) when status in 200..399, do: "test-status__code--good"
  defp status_class(%{status: _}), do: "test-status__code--bad"

  defp key_values_to_keyword_list(form_data, field) do
    form_data
    |> Map.get(field, [])
    |> Enum.map(fn %{key: key, value: value} -> {key, value} end)
  end

end
