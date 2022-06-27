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
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.Helpers.MetadataFormHelpers

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
      <div class="transformation-form">
        <div class="transformation-form__name">
          <%= label(f, :name, "Name", class: "label label--required") %>
          <%= text_input(f, :name, class: "transformation-name input transformation-form-fields", phx_debounce: "1000") %>
          <%= ErrorHelpers.error_tag(f.source, :name, bind_to_input: false) %>
        </div>

        <div class="transformation-form__type">
          <%= label(f, :type, DisplayNames.get(:transformationType), class: "label label--required") %>
          <%= select(f, :type, get_transformation_types(), [class: "select"]) %>
          <%= ErrorHelpers.error_tag(f.source, :type, bind_to_input: false) %>
        </div>
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

  defp get_transformation_types(), do: map_to_dropdown_options(MetadataFormHelpers.get_transformation_type_options())

  defp map_to_dropdown_options(options) do
    Enum.map(options, fn {actual_value, description} ->
      [key: description, value: actual_value]
    end)
  end
end
