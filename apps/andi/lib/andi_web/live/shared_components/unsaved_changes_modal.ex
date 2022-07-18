defmodule AndiWeb.UnsavedChangesModal do
  @moduledoc """
  LiveComponent for showing the unsaved changes modal
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="unsaved-changes-modal unsaved-changes-modal--<%= @visibility %>">
      <div class="modal-form-container">
        <h3>Unsaved Changes</h3>
        <p class="unsaved-changes-modal__message">
          You have unsaved changes within this<br> section. Do you wish to continue without saving?
        </p>
        <br>
        <div class="button-container">
          <button type="button" class="btn" phx-click="unsaved-changes-canceled">Cancel</a>
          <button type="button" class="btn submit_button continue-cancel-button" phx-click="force-cancel-edit">Continue</a>
        </div>
      </div>
    </div>
    """
  end
end
