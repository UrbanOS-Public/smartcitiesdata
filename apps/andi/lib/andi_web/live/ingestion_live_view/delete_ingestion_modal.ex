defmodule AndiWeb.IngestionLiveView.DeleteIngestionModal do
  @moduledoc """
  LiveComponent promting the user to cancel or delete the ingestion.
  Emits the "confirm-delete" event with id or "cancel-delete" event
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="confirm-delete-modal confirm-delete-modal--<%= @visibility %>">
      <div class="modal-form-container">
        <h3>Delete Ingestion</h3>
        <p>Are you sure? This ingestion will be deleted permanently.</p>
        <br>
        <div class="button-container">
          <button type="button" class="btn" phx-click="delete-canceled">Cancel</button>
          <button type="button" class="btn delete-button" phx-click="delete-confirmed">Delete</button>
        </div>
      </div>
    </div>
    """
  end
end
