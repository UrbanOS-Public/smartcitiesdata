defmodule AndiWeb.IngestionLiveView.Transformations.TransformationForm do
  @moduledoc """
  LiveComponent for editing an individual transformation
  """
  use Phoenix.LiveView
  require Logger

  def mount(_params, _assigns, socket) do
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok, socket}
  end

  def render(assigns) do
    ~L"""
    <div class="transformation">
      <p>Transformation</p>
    </div>
    """
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end
end
