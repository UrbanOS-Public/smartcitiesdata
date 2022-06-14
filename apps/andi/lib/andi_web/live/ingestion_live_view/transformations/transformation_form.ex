defmodule AndiWeb.IngestionLiveView.Transformations.TransformationForm do
  @moduledoc """
  LiveComponent for editing an individual transformation
  """
  use Phoenix.LiveView
  require Logger
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers

  def mount(_params, %{"transformation" => transformation}, socket) do
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok, assign(socket,
      transformation: transformation)}
  end

  def render(assigns) do
    ~L"""
    <%= f = form_for @transformation, "#", [ as: :form_data, phx_change: :validate, id: :transformation_form] %>
    <div class="transformation-form transformation-form__name">
      <%= label(f, :name, "Transformation Name", class: "label label--required") %>
      <%= text_input(f, :name, class: "transformation-name input transformation-form-fields", phx_debounce: "1000") %>
      <%= ErrorHelpers.error_tag(f, :transformation_name, bind_to_input: false) %>
    </div>

    </form>
    """
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end
end
