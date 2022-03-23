defmodule AndiWeb.EditLiveView.DeleteDatasetModal do
  @moduledoc """
  LiveComponent promting the user to cancel or delete the dataset
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="confirm-delete-modal confirm-delete-modal--<%= @visibility %>">
      <div class="modal-form-container">
        <h3>Delete Dataset</h3>
        <p>Are you sure? This dataset will be deleted permanently</p>
        <br>
        <div class="button-container">
          <button type="button" class="btn" phx-click="cancel-delete">Cancel</button>
          <button type="button" class="btn delete-button" phx-click="confirm-delete" phx-value-id=<%= @id %> >Delete</button>
        </div>
      </div>
    </div>
    """
  end
end
