defmodule AndiWeb.EditLiveView.ExtractStepForm do
  @moduledoc """
  LiveComponent for editing dataset URL
  """
  use Phoenix.LiveView
  # use AndiWeb.FormSection, schema_module: Andi.InputSchemas.Datasets.ExtractHttpStep
  import Phoenix.HTML
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias Andi.InputSchemas.StructTools
  alias AndiWeb.Views.HttpStatusDescriptions
  alias Andi.InputSchemas.Datasets
  alias Andi.InputSchemas.ExtractSteps
  alias AndiWeb.Helpers.FormTools

  def mount(_, %{"dataset" => dataset}, socket) do
    step =
      dataset
      |> get_in([:technical, :extractSteps])
      |> Andi.InputSchemas.StructTools.to_map()

    new_changeset =
      case Enum.empty?(step) do
        #TODO probably want to change this
        true ->
          %{type: "http", technical_id: dataset.technical.id}
          |> ExtractHttpStep.changeset()

        #TODO hd()
        false ->
          step
          |> hd()
          |> StructTools.to_map()
          |> ExtractHttpStep.changeset()
      end

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
            <%= hidden_input(f, :id) %>
            <%= hidden_input(f, :type) %>
            <%= hidden_input(f, :technical_id) %>

            <div class="component-edit-section--<%= @visibility %>">
              <div class="extract-step-form-edit-section form-grid">
                <div class="extract-step-form__type">
                  <%= label(f, :type, DisplayNames.get(:type), class: "label") %>
                  <%= select(f, :type, get_extract_step_types(), id: "step_type", class: "extract-step-form__type select") %>
                </div>

                <div class="extract-step-form__method">
                  <%= label(f, :method, DisplayNames.get(:method), class: "label label--required") %>
                  <%= select(f, :method, get_http_methods(), id: "http_method", class: "extract-step-form__method select") %>
                  <%= ErrorHelpers.error_tag(f, :type) %>
                </div>

                <div class="extract-step-form__url">
                  <%= label(f, :url, DisplayNames.get(:url), class: "label label--required") %>
                  <%= text_input(f, :url, class: "input full-width", disabled: @testing) %>
                  <%= ErrorHelpers.error_tag(f, :url) %>
                </div>

                <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_queryParams, css_label: "source-query-params", form: f, field: :queryParams ) %>

                <%= live_component(@socket, KeyValueEditor, id: :key_value_editor_headers, css_label: "source-headers", form: f, field: :headers ) %>

                <%= if input_value(f, :method) == "POST" do %>
                  <div class="extract-step-form__body">
                    <%= label(f, :body, DisplayNames.get(:body), class: "label") %>
                    <%= textarea(f, :body, class: "input full-width", disabled: @testing) %>
                    <%= ErrorHelpers.error_tag(f, :body) %>
                  </div>
                <% end %>

                <div class="extract-step-form__test-section">
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
    |> FormTools.adjust_extract_query_params_for_url()
    |> ExtractHttpStep.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data, "_target" => ["form_data", "queryParams" | _]}, socket) do
    form_data
    |> FormTools.adjust_extract_url_for_query_params()
    |> ExtractHttpStep.changeset_from_form_data()
    |> complete_validation(socket)
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> ExtractHttpStep.changeset()
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

    #TODO clean this up
    current_step_id = current_changes.id
    existing_step =
      case ExtractSteps.get(current_step_id) do
        nil -> %ExtractHttpStep{}
        struct -> struct
      end
    ExtractSteps.update(existing_step, current_changes)

    {:ok, dataset} = ExtractSteps.add_extract_query_param(current_step_id)
    new_changes =
      current_step_id
      |> ExtractSteps.get()
      |> StructTools.to_map()

    changeset = ExtractHttpStep.changeset(%ExtractHttpStep{}, new_changes)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("add", %{"field" => "headers"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()

    #TODO clean this up
    current_step_id = current_changes.id
    existing_step =
      case ExtractSteps.get(current_step_id) do
        nil -> %ExtractHttpStep{}
        struct -> struct
      end
    ExtractSteps.update(existing_step, current_changes)

    {:ok, dataset} = ExtractSteps.add_extract_header(current_step_id)
    new_changes =
      current_step_id
      |> ExtractSteps.get()
      |> StructTools.to_map()

    changeset = ExtractHttpStep.changeset(%ExtractHttpStep{}, new_changes)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "queryParams"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()

    current_step_id = current_changes.id
    existing_step =
      case ExtractSteps.get(current_step_id) do
        nil -> %ExtractHttpStep{}
        struct -> struct
      end
    ExtractSteps.update(existing_step, current_changes)

    {:ok, dataset} = ExtractSteps.remove_extract_query_param(current_step_id, id)
    new_changes =
      current_step_id
      |> ExtractSteps.get()
      |> StructTools.to_map()

    changeset = ExtractHttpStep.changeset(%ExtractHttpStep{}, new_changes)

    {:noreply, assign(socket, changeset: changeset)}
  end

  def handle_event("remove", %{"id" => id, "field" => "headers"}, socket) do
    current_changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()

    current_step_id = current_changes.id
    existing_step =
      case ExtractSteps.get(current_step_id) do
        nil -> %ExtractHttpStep{}
        struct -> struct
      end
    ExtractSteps.update(existing_step, current_changes)

    {:ok, dataset} = ExtractSteps.remove_extract_header(current_step_id, id)
    new_changes =
      current_step_id
      |> ExtractSteps.get()
      |> StructTools.to_map()

    changeset = ExtractHttpStep.changeset(%ExtractHttpStep{}, new_changes)

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

  # def handle_info(message, socket) do
  #   Logger.debug(inspect(message))
  #   {:noreply, socket}
  # end

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

  defp get_extract_step_types(), do: map_to_dropdown_options(Options.extract_step_type())
  defp get_http_methods(), do: map_to_dropdown_options(Options.http_method())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  #TODO probably try to extract this back into form_section
  def handle_event("save", _, socket) do
    AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{dataset_id: socket.assigns.dataset_id})
    save_draft(socket)
  end

  def handle_info(
    %{topic: "form-save", event: "save-all", payload: %{dataset_id: dataset_id}},
    %{assigns: %{dataset_id: dataset_id}} = socket
  ) do

    save_draft(socket)
  end

  defp save_draft(socket) do
    new_validation_status =
      case socket.assigns.changeset.valid? do
        true -> "valid"
        false -> "invalid"
      end

    changes =
      socket.assigns.changeset
      |> Ecto.Changeset.apply_changes()
      |> StructTools.to_map()
      |> IO.inspect()

    extract_step_id = changes.id
    existing_http_step =
      case ExtractSteps.get(extract_step_id) do
        nil -> %ExtractHttpStep{}
        struct -> struct
      end

    draft_changeset =
      ExtractHttpStep.changeset_for_draft(existing_http_step, changes)

    Andi.Repo.insert_or_update(draft_changeset)

    {:noreply, assign(socket, validation_status: new_validation_status)}
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{topic: "toggle-component-visibility"}, socket) do
    {:noreply, socket}
  end

  def handle_event("toggle-component-visibility", %{"component-expand" => next_component}, socket) do
    new_validation_status = get_new_validation_status(socket.assigns.changeset)

    AndiWeb.Endpoint.broadcast_from(self(), "toggle-visibility", "toggle-component-visibility", %{
          expand: next_component,
          dataset_id: socket.assigns.dataset_id
                                    })

    {:noreply, assign(socket, visibility: "collapsed", validation_status: new_validation_status)}
  end

  def handle_event("toggle-component-visibility", _, socket) do
    current_visibility = Map.get(socket.assigns, :visibility)

    new_visibility =
      case current_visibility do
        "expanded" -> "collapsed"
        "collapsed" -> "expanded"
      end

    {:noreply, assign(socket, visibility: new_visibility) |> update_validation_status()}
  end

  def update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility}} = socket)
  when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
    assign(socket, validation_status: get_new_validation_status(socket.assigns.changeset))
  end

  def update_validation_status(%{assigns: %{visibility: visibility}} = socket), do: assign(socket, validation_status: visibility)

  defp get_new_validation_status(changeset) do
    case changeset.valid? do
      true -> "valid"
      false -> "invalid"
    end
  end
end
