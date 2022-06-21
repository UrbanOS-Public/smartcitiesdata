defmodule AndiWeb.IngestionLiveView.Transformations.TransformationForm do
  @moduledoc """
  LiveComponent for editing an individual transformation
  """
  use Phoenix.LiveView
  require Logger
  import Phoenix.HTML.Form

  alias AndiWeb.ErrorHelpers
  alias Andi.InputSchemas.Ingestions.Transformation
  alias Andi.InputSchemas.Ingestions.Transformations
  alias Andi.InputSchemas.InputConverter

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
    <%= hidden_input(f, :id, value: @transformation_changeset.changes.id) %>
      <div class="transformation-form transformation-form__name">
        <%= label(f, :name, "Name", class: "label label--required") %>
        <%= text_input(f, :name, class: "transformation-name input transformation-form-fields", phx_debounce: "1000") %>
        <%= ErrorHelpers.error_tag(f.source, :name, bind_to_input: false) %>
      </div>
    </form>
    """
  end

  def handle_info(
        %{topic: "form-save", event: "save-all", payload: %{ingestion_id: ingestion_id}},
        %{
          assigns: %{
            transformation_changeset: transformation_changeset
          }
        } = socket
      ) do
    changes =
      InputConverter.form_changes_from_changeset(transformation_changeset)
      |> Map.put(:ingestion_id, ingestion_id)

    transformation_changeset.changes.id
    |> Transformations.get()
    |> Transformations.update(changes)

    {:noreply,
     assign(socket,
       validation_status: "valid"
     )}
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    new_changeset = Transformation.changeset_from_form_data(form_data)

    {:noreply, assign(socket, transformation_changeset: new_changeset)}
  end
end
