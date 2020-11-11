defmodule AndiWeb.ExtractSteps.ExtractDateStepForm do
  @moduledoc """
  LiveComponent for an extract step with type HTTP
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import AndiWeb.Helpers.ExtractStepHelpers
  require Logger

  alias Andi.InputSchemas.Datasets.ExtractDateStep
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.ExtractSteps.ExtractStepHeader

  def mount(socket) do
    {:ok,
     assign(socket,
       visibility: "expanded",
       validation_status: "collapsed",
       example_output: nil
     )}
  end

  def render(assigns) do
    ~L"""
    <div id="step-<%= @id %>" class="extract-step-container extract-date-step-form">

        <%= live_component(@socket, ExtractStepHeader, step_name: "Date", step_id: @id) %>

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
    {updated_changeset, updated_socket} =
      form_data
      |> AtomicMap.convert(safe: false, underscore: false)
      |> ExtractDateStep.changeset()
      |> update_example_output(socket)

    complete_validation(updated_changeset, updated_socket)
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def handle_event("get_example_output", _, socket) do
    {:noreply, assign(socket, example_output: get_example_output(socket.assigns.changeset))}
  end

  defp get_time_units(), do: map_to_dropdown_options(Options.time_units())

  defp update_example_output(changeset, socket) do
    {changeset, assign(socket, example_output: get_example_output(changeset))}
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
