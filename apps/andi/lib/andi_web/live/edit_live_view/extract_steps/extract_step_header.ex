defmodule AndiWeb.ExtractSteps.ExtractStepHeader do
  @moduledoc """
  LiveComponent for common extract step header
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="extract-step-header full-width">
      <h3><%= @step_name %></h3>
      <div class="edit-buttons">
        <span class="extract-step-header__up material-icons" phx-click="move-extract-step" phx-value-id=<%= @step_id %> phx-value-move-index="-1">keyboard_arrow_up</span>
        <span class="extract-step-header__down material-icons" phx-click="move-extract-step" phx-value-id=<%= @step_id %> phx-value-move-index="1">keyboard_arrow_down</span>
        <div class="extract-step-header__remove"></div>
      </div>
    </div>
    """
  end
end
