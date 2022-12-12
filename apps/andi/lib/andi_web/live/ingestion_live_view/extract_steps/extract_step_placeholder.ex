defmodule AndiWeb.ExtractSteps.ExtractPlaceholderStepForm do
  @moduledoc """
  LiveComponent for an extract step with a type that does not currently have a ui component
  """
  use Phoenix.LiveComponent

  alias AndiWeb.ExtractSteps.ExtractStepHeader

  def mount(socket) do
    {:ok, socket}
  end

  def render(assigns) do
    ~L"""
    <div id="step-<%= @id %>" class="extract-step-container extract-secret-step-form">

      <%= live_component(@socket, ExtractStepHeader, step_name: String.upcase(@extract_step.type), step_id: @id) %>

      <p>This type of extract step is not currently able to be edited</p>

    </div>
    """
  end
end
