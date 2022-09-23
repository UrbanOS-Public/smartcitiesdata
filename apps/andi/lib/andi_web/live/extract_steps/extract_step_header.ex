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
        <button type="button" class="btn btn--right btn--transparent extract-step-header__up material-icons" phx-click="move-extract-step" phx-value-id="<%= @step_id %>" phx-value-move-index="-1">keyboard_arrow_up</button>
        <button type="button" class="btn btn--right btn--transparent extract-step-header__down material-icons" phx-click="move-extract-step" phx-value-id="<%= @step_id %>" phx-value-move-index="1">keyboard_arrow_down</button>
        <button type="button" class="btn btn--right btn--transparent extract-step-header__remove" phx-click="remove-extract-step" phx-value-id="<%= @step_id %>"></button>
      </div>
    </div>
    """
  end
end
