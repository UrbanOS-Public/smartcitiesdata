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
        <button type="button" class="btn btn--right btn--transparent primary-color extract-step-header__up material-icons" phx-click="move-extract-step" phx-value-id="<%= @step_id %>" phx-value-move-index="-1" phx-target="<%= @parent_id %>" aria-label="move <%= @step_name %> ingest step up">keyboard_arrow_up</button>
        <button type="button" class="btn btn--right btn--transparent primary-color extract-step-header__down material-icons" phx-click="move-extract-step" phx-value-id="<%= @step_id %>" phx-value-move-index="1" phx-target="<%= @parent_id %>" aria-label="move <%= @step_name %> ingest step down">keyboard_arrow_down</button>

        <button type="button" class="btn btn--right btn--transparent extract-step-header__remove material-icons" phx-click="remove-extract-step" phx-value-id="<%= @step_id %>" phx-target="<%= @parent_id %>" aria-label="delete <%= @step_name %> ingest step">delete_outline</button>
      </div>
    </div>
    """
  end
end
