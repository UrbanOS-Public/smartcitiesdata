defmodule AndiWeb.EditLiveView.PublishSuccessModal do
  @moduledoc """
  LiveComponent promting the user to return home or stay on the edit page after successful publish
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="publish-success-modal publish-success-modal--<%= @visibility %>">
      <div class="modal-form-container">
        <p>Published successfully</p>
        <br>
        <div class="button-container-publish-success">
          <button type="button" class="btn" phx-click="cancel-edit">RETURN HOME</button>
          <button type="button" class="btn submit_button" phx-click="reload-page" >CONTINUE EDITING</button>
        </div>
      </div>
    </div>
    """
  end
end
