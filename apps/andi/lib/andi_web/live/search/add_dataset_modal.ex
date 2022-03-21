defmodule AndiWeb.Search.AddDatasetModal do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <div class="add-dataset-modal add-dataset-modal--<%= @visibility %>">
      <div class="modal-form-container">
          <p>Hello! I'm a modal!</p>
      </div>
    </div>
    """
  end
end
