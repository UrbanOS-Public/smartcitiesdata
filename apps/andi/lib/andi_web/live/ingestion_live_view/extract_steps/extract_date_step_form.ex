defmodule AndiWeb.ExtractSteps.ExtractDateStepForm do
  @moduledoc """
  LiveComponent for an extract step with type HTTP
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import AndiWeb.Helpers.ExtractStepHelpers
  require Logger

  alias Andi.InputSchemas.Ingestions.ExtractDateStep
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias Ecto.Changeset

  def mount(socket) do
    {:ok,
     assign(socket,
       visibility: "expanded",
       validation_status: "collapsed"
     )}
  end

  def render(assigns) do
    example_output = get_example_output(assigns.changeset)

    ~L"""
    <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: @myself, as: :form_data, id: @id] %>

        <div class="component-edit-section--<%= @visibility %>">
          <div class="extract-date-step-form-edit-section form-grid">
            <div class="extract-date-step-form__destination">
              <%= label(f, :destination, DisplayNames.get(:destination), class: "label label--required", for: "#{@id}_date_destination") %>
              <%= text_input(f, :destination, [id: "#{@id}_date_destination", required: true, class: "input"]) %>
              <%= ErrorHelpers.error_tag(f, :destination, bind_to_input: false, id: "#{@id}_date_destination_error") %>
            </div>

            <div class="extract-date-step-form__deltaTimeUnit">
              <%= label(f, :deltaTimeUnit, DisplayNames.get(:deltaTimeUnit), class: "label", for: "#{@id}_date_delta_time_unit") %>
              <%= select(f, :deltaTimeUnit, get_time_units(), id: "#{@id}_date_delta_time_unit", class: "extract-date-step-form__delta_time_unit select") %>
              <%= ErrorHelpers.error_tag(f, :deltaTimeUnit, id: "#{@id}_date_delta_time_unit_error") %>
            </div>

            <div class="extract-date-step-form__deltaTimeValue">
              <%= label(f, :deltaTimeValue, DisplayNames.get(:deltaTimeValue), class: "label", for: "#{@id}_date_delta_time_value") %>
              <%= text_input(f, :deltaTimeValue, id: "#{@id}_date_delta_time_value", class: "extract-date-step-form__delta_time_value input") %>
              <%= ErrorHelpers.error_tag(f, :deltaTimeValue, id: "#{@id}_date_delta_time_value_error") %>
            </div>

            <div class="extract-date-step-form__format">
              <div class="help-text-label">
                <%= label(f, :format, "Format", class: "label label--required", for: "step_#{@id}_date_format") %>
                <a href="https://hexdocs.pm/timex/Timex.Format.DateTime.Formatters.Default.html" target="_blank">Help</a>
              </div>
              <%= text_input(f, :format, [id: "step_#{@id}_date_format", class: "extract-date-step-form__format input", required: true]) %>
              <%= ErrorHelpers.error_tag(f, :format, id: "#{@id}_date_format_error") %>
            </div>

            <div class="extract-date-step-form__output">
              <div class="label">Output <span class="label__subtext">All times are in UTC</span></div>
              <div class="example-output">
                <%= example_output %>
              </div>
            </div>

          </div>
        </div>
      </form>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    extract_step = ExtractDateStep.changeset(socket.assigns.changeset, form_data)

    AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm.update_extract_step(extract_step, socket.assigns.id)

    {:noreply, socket}
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  defp get_time_units(), do: map_to_dropdown_options(Options.time_units())

  defp update_example_output(changeset, socket) do
    {changeset, assign(socket, example_output: get_example_output(changeset))}
  end

  defp get_example_output(%{valid?: false}), do: "Please clear errors before output can be shown"

  defp get_example_output(%{changes: %{deltaTimeUnit: ""}} = changeset) do
    format = Changeset.get_field(changeset, :format)

    Timex.now()
    |> Timex.format!(format)
  end

  defp get_example_output(changeset) do
    delta_time_unit = Changeset.get_change(changeset, :deltaTimeUnit, "days") |> String.to_atom()
    delta_time_value = Changeset.get_change(changeset, :deltaTimeValue, 0)
    format = Changeset.get_field(changeset, :format)

    Timex.now()
    |> Timex.shift([{delta_time_unit, delta_time_value}])
    |> Timex.format!(format)
  end
end
