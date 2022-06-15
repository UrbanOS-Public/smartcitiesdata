defmodule AndiWeb.IngestionLiveView.Transformations.TransformationForm do
  @moduledoc """
  LiveComponent for editing an individual transformation
  """
  use Phoenix.LiveView
  require Logger
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias Andi.InputSchemas.Ingestions.Transformation

  def mount(_params, %{"transformation_changeset" => transformation_changeset}, socket) do
    AndiWeb.Endpoint.subscribe("form-save")

    {:ok,
     assign(socket,
       transformation_changeset: transformation_changeset
     )}
  end

  def render(assigns) do
    ~L"""

    <div class="transformation-header">
      <p>Transformation</p>
    </div>

    <%= f = form_for @transformation_changeset, "#", [ as: :form_data, phx_change: :validate, id: :transformation_form] %>
      <div class="transformation-form transformation-form__name">
        <%= label(f, :name, "Name", class: "label label--required") %>
        <%= text_input(f, :name, class: "transformation-name input transformation-form-fields", phx_debounce: "1000") %>
        <%= ErrorHelpers.error_tag(f.source, :name, bind_to_input: false) %>
      </div>
    </form>
    """
  end

  def handle_info(%{topic: "form-save"}, socket) do
    {:noreply, socket}
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    new_changeset = Transformation.changeset_from_form_data(form_data)

    {:noreply, assign(socket, transformation_changeset: new_changeset)}
  end
end
