defmodule AndiWeb.DataDictionary.OverwriteSchemaModal do
  @moduledoc """
  LiveComponent for prompting the user if they would like to overwrite the existing schema
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="overwrite-schema-modal overwrite-schema-modal--<%= @visibility %>">
      <div class="modal-form-container" x-trap="<%= @visibility === "visible" %>">
        <h3>Warning!</h3>
        <p class="overwrite-schema-modal__message">
          Uploading this file will overwrite the existing schema.<br> Are you sure you would like to continue?
        </p>
        <br>
        <div class="button-container">
          <button type="button" class="btn" phx-click="overwrite-schema-cancelled">Cancel</a>
          <button type="button" class="btn submit_button" phx-click="overwrite-schema">Continue</a>
        </div>
      </div>
    </div>
    """
  end
end
