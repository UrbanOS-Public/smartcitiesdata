defmodule AndiWeb.ExtractSteps.ExtractDateStepForm do
  @moduledoc """
  LiveComponent for an extract step with type HTTP
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Datasets.ExtractDateStep
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames

  def mount(socket) do
    {:ok,
     assign(socket,
       testing: false,
       test_results: nil,
       visibility: "expanded",
       validation_status: "collapsed",
       example_output: nil
     )}
  end

  def render(assigns) do
    ~L"""
    <div id="step-<%= @id %>" class="extract-step-container extract-date-step-form">
        <div class="extract-step-header full-width">
          <h3>Date</h3>
          <div class="edit-buttons">
            <span class="extract-step-header__up material-icons" phx-click="move-extract-step" phx-value-id=<%= @id %> phx-value-move-index="-1">keyboard_arrow_up</span>
            <span class="extract-step-header__down material-icons" phx-click="move-extract-step" phx-value-id=<%= @id %> phx-value-move-index="1">keyboard_arrow_down</span>
            <div class="extract-step-header__remove"></div>
          </div>
        </div>

        <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: "#step-#{@id}", as: :form_data] %>
          <%= hidden_input(f, :id) %>
          <%= hidden_input(f, :type) %>
          <%= hidden_input(f, :technical_id) %>

          <div class="component-edit-section--<%= @visibility %>">
            <div class="extract-date-step-form-edit-section form-grid">
              <div class="extract-date-step-form__destination">
                <%= label(f, :destination, DisplayNames.get(:destination), class: "label label--required") %>
                <%= text_input(f, :destination, id: "date_destination", class: "extract-date-step-form__destination input", phx_focus: :get_example_output, phx_target: "#step-#{@id}") %>
                <%= ErrorHelpers.error_tag(f, :destination) %>
              </div>

              <div class="extract-date-step-form__deltaTimeUnit">
                <%= label(f, :deltaTimeUnit, DisplayNames.get(:deltaTimeUnit), class: "label") %>
                <%= select(f, :deltaTimeUnit, get_time_units(), id: "date_delta_time_unit", class: "extract-date-step-form__delta_time_unit select", phx_focus: :get_example_output, phx_target: "#step-#{@id}") %>
                <%= ErrorHelpers.error_tag(f, :deltaTimeUnit) %>
              </div>

              <div class="extract-date-step-form__deltaTimeValue">
                <%= label(f, :deltaTimeValue, DisplayNames.get(:deltaTimeValue), class: "label") %>
                <%= text_input(f, :deltaTimeValue, id: "date_delta_time_value", class: "extract-date-step-form__delta_time_value input", phx_focus: :get_example_output, phx_target: "#step-#{@id}") %>
                <%= ErrorHelpers.error_tag(f, :deltaTimeValue) %>
              </div>

              <div class="extract-date-step-form__format">
                <div class="help-text-label">
                  <%= label(f, :format, "Format", class: "label label--required") %>
                  <a href="https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html" target="_blank">Help</a>
                </div>
                <%= text_input(f, :format, id: "date_format", class: "extract-date-step-form__format input", phx_focus: :get_example_output, phx_target: "#step-#{@id}") %>
                <%= ErrorHelpers.error_tag(f, :format) %>
              </div>

              <div class="extract-date-step-form__output">
                <div class="label">Output <span class="label__subtext">All times are in UTC</span></div>
                <%= if @example_output != nil do %>
                  <div class="example-output">
                    <%= @example_output %>
                  </div>
                <% end %>
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

  def handle_event("get_example_output", _, socket) do
    {:noreply, assign(socket, example_output: get_example_output(socket.assigns.changeset))}
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

  defp get_time_units(), do: map_to_dropdown_options(Options.time_units())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} -> [key: description, value: actual_value] end)
  end

  defp update_validation_status(%{assigns: %{validation_status: validation_status, visibility: visibility}} = socket)
       when validation_status in ["valid", "invalid"] or visibility == "collapsed" do
    new_status = get_new_validation_status(socket.assigns.changeset)
    send(socket.parent_pid, {:validation_status, {socket.assigns.extract_step.id, new_status}})
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
    send(self(), {:step_update, socket.assigns.id, new_changeset})

    updated_example_output = get_example_output(new_changeset)
    {:noreply, assign(socket, changeset: new_changeset, example_output: updated_example_output) |> update_validation_status()}
  end

  defp get_example_output(%{valid?: false}), do: nil

  defp get_example_output(%{changes: %{deltaTimeUnit: ""}} = changeset) do
    format = Ecto.Changeset.get_field(changeset, :format)

    Timex.now()
    |> Timex.format!(format)
  end

  defp get_example_output(changeset) do
    delta_time_unit = Ecto.Changeset.get_change(changeset, :deltaTimeUnit, "days") |> String.to_atom()
    delta_time_value = Ecto.Changeset.get_change(changeset, :deltaTimeValue, 0)
    format = Ecto.Changeset.get_field(changeset, :format)

    Timex.now()
    |> Timex.shift([{delta_time_unit, delta_time_value}])
    |> Timex.format!(format)
  end
end
