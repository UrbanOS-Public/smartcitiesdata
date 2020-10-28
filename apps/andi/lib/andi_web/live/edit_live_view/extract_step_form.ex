defmodule AndiWeb.EditLiveView.ExtractStepForm do
  @moduledoc """
  LiveComponent for editing dataset extract steps
  """
  use Phoenix.LiveView
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
  alias Andi.InputSchemas.ExtractHttpSteps
  alias AndiWeb.Helpers.FormTools

  def mount(_, %{"dataset" => dataset}, socket) do
    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       extract_steps: get_in(dataset, [:technical, :extractSteps]),
       testing: false,
       test_results: nil,
       visibility: "collapsed",
       validation_status: "collapsed",
       dataset_id: dataset.id,
       technical_id: dataset.technical.id
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

        <div class="add-step-section">
          <button type="button" phx-click="add-extract-step" class="btn">Add Step</button>
        </div>

        <%= for extract_step <- @extract_steps do %>
          <%= live_render(@socket, AndiWeb.ExtractSteps.ExtractHttpStepForm, id: extract_step.id, session: %{"extract_step" => extract_step, "technical_id" => @technical_id, "dataset_id" => @dataset_id}) %>
        <% end %>

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
    """
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

  def handle_event("save", _, socket) do
    AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{dataset_id: socket.assigns.dataset_id})

    {:noreply, socket}
  end

  def handle_event("add-extract-step", _, socket) do
    technical_id = socket.assigns.technical_id

    new_extract_step =
      ExtractHttpStep.changeset_from_andi_step(nil, technical_id)
      |> Ecto.Changeset.apply_changes()
      |> Andi.InputSchemas.StructTools.to_map()

    ExtractHttpSteps.update(new_extract_step)

    {:noreply, assign(socket, extract_steps: ExtractHttpSteps.all_for_technical(technical_id))}
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

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{topic: "toggle-component-visibility"}, socket) do
    {:noreply, socket}
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

  # defp save_draft(socket) do
  #   new_validation_status =
  #     case socket.assigns.changeset.valid? do
  #       true -> "valid"
  #       false -> "invalid"
  #     end

  #   new_changes =
  #     socket.assigns.changeset
  #     |> Andi.InputSchemas.InputConverter.form_changes_from_changeset()

  #   Andi.InputSchemas.Datasets.update_from_form(socket.assigns.dataset_id, %{extractSteps: [new_changes]})

  #   {:noreply, assign(socket, validation_status: new_validation_status)}
  # end

  defp update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility}} = socket)
       when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
    assign(socket, validation_status: get_new_validation_status(socket.assigns.changeset))
  end

  defp update_validation_status(%{assigns: %{visibility: visibility}} = socket), do: assign(socket, validation_status: visibility)

  defp get_new_validation_status(changeset) do
    case changeset.valid? do
      true -> "valid"
      false -> "invalid"
    end
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset) |> update_validation_status()}
  end
end
