defmodule AndiWeb.ExtractSteps.ExtractDateStepForm do
  @moduledoc """
  LiveComponent for an extract step with type HTTP
  """
  use Phoenix.LiveView
  import Phoenix.HTML
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Datasets.ExtractStep
  alias Andi.InputSchemas.Datasets.ExtractDateStep
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.ExtractDateSteps
  alias AndiWeb.Helpers.FormTools

  def mount(_, %{"extract_step" => extract_step, "dataset_id" => dataset_id, "technical_id" => technical_id}, socket) do
    new_changeset =
      extract_step
      |> Andi.InputSchemas.StructTools.to_map()
      |> ExtractStep.changeset()

    AndiWeb.Endpoint.subscribe("toggle-visibility")
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       extract_step_id: extract_step.id,
       changeset: new_changeset,
       testing: false,
       test_results: nil,
       visibility: "expanded",
       validation_status: "collapsed",
       dataset_id: dataset_id,
       technical_id: technical_id
     )}
  end

  def render(assigns) do
    ~L"""
        <div class="form-section extract-step-container extract-date-step-form">
          <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data] %>
            <%= hidden_input(f, :id) %>
            <%= hidden_input(f, :type) %>
            <%= hidden_input(f, :technical_id) %>

            <div class="extract-step-form__type">
              <h3>Date</h3>
            </div>

            <div class="component-edit-section--<%= @visibility %>">
              <div class="extract-step-form-edit-section form-grid">
                <div class="extract-step-form__destination">
                  <%= label(f, :destination, DisplayNames.get(:destination), class: "label label--required") %>
                  <%= text_input(f, :destination, id: "date_destination", class: "extract-step-form__destination input") %>
                  <%= ErrorHelpers.error_tag(f, :destination) %>
                </div>
                <div class="extract-step-form__deltaTimeUnit">
                  <%= label(f, :deltaTimeUnit, DisplayNames.get(:deltaTimeUnit), class: "label label--required") %>
                  <%= select(f, :deltaTimeUnit, get_time_units(), id: "date_delta_time_unit", class: "extract-step-form__delta_time_unit select") %>
                  <%= ErrorHelpers.error_tag(f, :deltaTimeUnit) %>
                </div>
                <div class="extract-step-form__deltaTimeValue">
                  <%= label(f, :deltaTimeValue, DisplayNames.get(:deltaTimeValue), class: "label label--required") %>
                  <%= text_input(f, :deltaTimeValue, id: "date_delta_time_value", class: "extract-step-form__delta_time_value input") %>
                  <%= ErrorHelpers.error_tag(f, :deltaTimeValue) %>
                </div>
                <div class="extract-step-form__format">
                  <%= label(f, :format, DisplayNames.get(:format), class: "label label--required") %>
                  <%= text_input(f, :format, id: "date_format", class: "extract-step-form__format input") %>
                  <%= ErrorHelpers.error_tag(f, :format) %>
                </div>
              </div>
            </div>
          </form>
        </div>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> ExtractDateStep.changeset()
    |> complete_validation(socket)
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  defp get_time_units(), do: []

  defp disabled?(true), do: "disabled"
  defp disabled?(_), do: ""

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  defp update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility}} = socket)
       when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
    new_status = get_new_validation_status(socket.assigns.changeset)
    send(socket.parent_pid, {:validation_status, new_status})
    assign(socket, validation_status: new_status)
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
