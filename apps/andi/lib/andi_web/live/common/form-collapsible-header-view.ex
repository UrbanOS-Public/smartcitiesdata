defmodule AndiWeb.FormCollapsibleHeader do
  @moduledoc """
  LiveComponent for the collapsible header used in forms
  """
  use Phoenix.LiveComponent
  require Logger

  def component_id(step), do: "#{step}-collapsible-header-view"

  def mount(_params, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    {visible, action} = if assigns.visible?, do: {"expanded", "MINIMIZE"}, else: {"collapsed", "EDIT"}

    ~L"""
    <div class="component-header" phx-click="toggle-component-visibility" phx-target="<%= @myself %>">
      <div class="section-number">
        <div class="component-number component-number--<%= @validation_status %>"><%= @order %></div>
        <div class="component-number-status--<%= @validation_status %>"></div>
      </div>
      <div class="component-title full-width">
        <h2 class="component-title-text component-title-text--<%= visible %> "><%= @step %></h2>
        <button aria-label="<%= @step %> <%= action %>" type="button" class="btn btn--right btn--transparent component-title-button">
          <div class="component-title-action">
            <div class="component-title-action-text--<%= visible %>"><%= action %></div>
            <div class="component-title-icon--<%= visible %>"></div>
          </div>
        </button>
      </div>
    </div>
    """
  end

  def handle_event("toggle-component-visibility", _, socket) do
    current_visibility = Map.get(socket.assigns, :visible?)
    socket.assigns.visibility_change_callback.(!current_visibility)

    {:noreply, socket}
  end
end
