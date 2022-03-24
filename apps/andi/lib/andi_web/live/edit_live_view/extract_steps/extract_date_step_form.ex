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
