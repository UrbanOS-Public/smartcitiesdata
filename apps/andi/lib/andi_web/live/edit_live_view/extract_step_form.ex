defmodule AndiWeb.EditLiveView.ExtractStepForm do
  @moduledoc """
  LiveComponent for editing dataset extract steps
  """
  use Phoenix.LiveView
  import Phoenix.HTML
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Datasets.ExtractStep
  alias Andi.InputSchemas.Datasets.ExtractHttpStep
  alias Andi.InputSchemas.Datasets.ExtractDateStep
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias Andi.InputSchemas.StructTools
  alias AndiWeb.Views.HttpStatusDescriptions
  alias Andi.InputSchemas.ExtractSteps
  alias AndiWeb.Helpers.FormTools
  alias AndiWeb.ExtractSteps.ExtractDateStepForm
  alias AndiWeb.ExtractSteps.ExtractHttpStepForm
  alias Andi.InputSchemas.InputConverter

  def mount(params, %{"dataset" => dataset}, socket) do
    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")

    extract_steps = get_in(dataset, [:technical, :extractSteps])
    extract_step_changesets =
      Enum.reduce(extract_steps, %{}, fn extract_step, acc ->
        changeset = ExtractStep.form_changeset_from_andi_extract_step(extract_step)
        Map.put(acc, extract_step.id, changeset)
      end)

    {:ok,
     assign(socket,
       extract_steps: extract_steps,
       extract_step_changesets: extract_step_changesets,
       testing: false,
       visibility: "expanded",
       validation_status: "collapsed",
       validation_map: %{},
       dataset_id: dataset.id,
       technical_id: dataset.technical.id,
       new_step_type: ""
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
          <div class="add-step">
            <%= select(:form, :step_type, get_extract_step_types(), phx_blur: "update_new_step_type", selected: @new_step_type, id: "extract_step_type", class: "extract-step-form__step-type select") %>
            <button class="btn" type="button" phx-click="add-extract-step">Add Step</button>
          </div>

          <%= for extract_step <- @extract_steps do %>
            <% component_module_to_render = render_extract_step_form(extract_step) %>
            <% step_changeset = Map.get(@extract_step_changesets, extract_step.id) %>

            <hr>
            <%= live_component(@socket, component_module_to_render, id: extract_step.id, extract_step: extract_step, technical_id: @technical_id, dataset_id: @dataset_id, changeset: step_changeset) %>
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
      </div>
    """
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

  def handle_event("save", _, %{assigns: %{extract_step_changesets: extract_step_changesets}} = socket) do
    AndiWeb.Endpoint.broadcast_from(self(), "form-save", "save-all", %{dataset_id: socket.assigns.dataset_id})

    save_step_changesets(extract_step_changesets)

    {:noreply, assign(socket, validation_status: get_new_validation_status(extract_step_changesets))}
  end

  def handle_event("update_new_step_type", %{"value" => value}, socket) do
    {:noreply, assign(socket, new_step_type: value)}
  end

  def handle_event("add-extract-step", _, %{assigns: %{new_step_type: ""}} = socket) do
    {:noreply, socket}
  end

  def handle_event("add-extract-step", _, socket) do
    step_type = socket.assigns.new_step_type
    technical_id = socket.assigns.technical_id
    {:ok, new_extract_step} = ExtractSteps.create(step_type, technical_id)
    new_extract_step_changeset = ExtractStep.form_changeset_from_andi_extract_step(new_extract_step)
    updated_changeset_map = Map.put(socket.assigns.extract_step_changesets, new_extract_step.id, new_extract_step_changeset)

    all_steps_for_technical = ExtractSteps.all_for_technical(technical_id)
    {:noreply, assign(socket, extract_steps: all_steps_for_technical, extract_step_changesets: updated_changeset_map)}
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

  def handle_info(
    %{topic: "form-save", event: "save-all", payload: %{dataset_id: dataset_id}},
    %{assigns: %{extract_step_changesets: extract_step_changesets, dataset_id: dataset_id}} = socket
  ) do
    save_step_changesets(extract_step_changesets)
    {:noreply, assign(socket, validation_status: get_new_validation_status(extract_step_changesets))}
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{topic: "toggle-component-visibility"}, socket) do
    {:noreply, socket}
  end

  def handle_info({:step_update, step_id, new_changeset}, socket) do
    updated_extract_step_changesets =
      socket.assigns.extract_step_changesets
      |> Map.put(step_id, new_changeset)

    {:noreply, assign(socket, extract_step_changesets: updated_extract_step_changesets) |> update_validation_status()}
  end

  def handle_info(
        {:validation_status, {step_id, status}},
        %{assigns: %{validation_status: old_status, validation_map: validation_map}} = socket
      ) do
    new_map = Map.put(validation_map, step_id, status)

    new_status =
      case Enum.any?(new_map, fn {id, status} -> status == "invalid" end) do
        false -> "valid"
        true -> "invalid"
      end

    {:noreply, assign(socket, validation_map: new_map, validation_status: new_status)}
  end

  # This handle_info takes care of all exceptions in a generic way.
  # Expected errors should be handled in specific handlers.
  # Flags should be reset here.
  def handle_info({:EXIT, _pid, {_error, _stacktrace}}, socket) do
    send(socket.parent_pid, :page_error)
    {:noreply, assign(socket, page_error: true, testing: false, save_success: false)}
  end

  defp save_step_changesets(extract_step_changesets) do
    Enum.each(extract_step_changesets, fn {id, changeset} ->
      changes = InputConverter.form_changes_from_changeset(changeset)

      id
      |> ExtractSteps.get()
      |> Map.put(:context, changes)
      |> ExtractSteps.update()
    end)
  end


  defp render_extract_step_form(%{type: "http"}), do: ExtractHttpStepForm

  defp render_extract_step_form(%{type: "date"}), do: ExtractDateStepForm

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

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  defp update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility}} = socket)
       when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
    assign(socket, validation_status: get_new_validation_status(socket.assigns.extract_step_changesets))
  end

  defp update_validation_status(%{assigns: %{visibility: visibility}} = socket), do: assign(socket, validation_status: visibility)

  defp get_new_validation_status(step_changesets) do
    case Enum.any?(step_changesets, fn {id, changeset} -> not changeset.valid? end) do
      true -> "invalid"
      false -> "valid"
    end
  end

  defp complete_validation(changeset, socket) do
    new_changeset = Map.put(changeset, :action, :update)
    send(socket.parent_pid, :form_update)

    {:noreply, assign(socket, changeset: new_changeset) |> update_validation_status()}
  end
end
