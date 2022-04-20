defmodule AndiWeb.ConfirmDeleteModal do
  @moduledoc """
  LiveComponent promting the user to cancel or delete the object.
  Emits the "confirm-delete" event with id or "cancel-delete" event
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="confirm-delete-modal confirm-delete-modal--<%= @visibility %>">
      <div class="modal-form-container">
        <h3><%= "Delete #{@type}" %></h3>
        <p><%= "Are you sure? This #{@type} will be deleted permanently." %></p>
        <br>
        <div class="button-container">
          <button type="button" class="btn cancel-delete-button" phx-click="delete-canceled">Cancel</button>
          <button type="button" class="btn delete-button" phx-click="delete-confirmed" phx-value-id=<%= @id %>>Delete</button>
        </div>
      </div>
    </div>
    """
  end
end
