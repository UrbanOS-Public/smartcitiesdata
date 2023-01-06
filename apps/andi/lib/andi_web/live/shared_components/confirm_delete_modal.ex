defmodule AndiWeb.ConfirmDeleteModal do
  @moduledoc """
  LiveComponent promting the user to cancel or delete the object.
  Emits the "confirm-delete" event with id or "cancel-delete" event
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="confirm-delete-modal confirm-delete-modal--<%= @visibility %>">
      <div class="modal-form-container" x-trap="<%= @visibility === "visible" %>">
        <h2 class="confirm-delete-header"><%= "Delete #{@type}" %></h3>
        <p><%= "Are you sure? This #{@type} will be deleted permanently." %></p>
        <br>
        <div class="button-container">
          <button id="confirm-cancel-button" type="button" class="btn btn--cancel" phx-click="delete-canceled">Cancel</button>
          <button id="confirm-delete-button" type="button" class="btn btn--danger btn--delete" phx-click="delete-confirmed" phx-value-id=<%= @id %>>
            <span class="delete-icon material-icons">delete</span>
            Delete
          </button>
        </div>
      </div>
    </div>
    """
  end
end
