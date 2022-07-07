defmodule AndiWeb.ExtractSteps.ExtractS3StepForm do
  @moduledoc """
  LiveComponent for an extract step with type s3
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import AndiWeb.Helpers.ExtractStepHelpers
  require Logger

  alias Andi.InputSchemas.Ingestions.ExtractS3Step
  alias Andi.InputSchemas.Ingestions.ExtractHeader
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.ExtractSteps.ExtractStepHeader

  def mount(socket) do
    {:ok,
     assign(socket,
       visibility: "expanded",
       validation_status: "collapsed"
     )}
  end

  def render(assigns) do
    ~L"""
    <div id="step-<%= @id %>" class="extract-step-container extract-s3-step-form">

      <%= live_component(@socket, ExtractStepHeader, step_name: "S3", step_id: @id) %>

      <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: "#step-#{@id}", as: :form_data] %>
        <div class="component-edit-section--<%= @visibility %>">
          <div class="extract-s3-step-form-edit-section form-grid">

            <div class="extract-s3-step-form__url">
              <%= label(f, :url, DisplayNames.get(:url), class: "label label--required") %>
              <%= text_input(f, :url, id: "step_#{@id}__s3_url", class: "input full-width") %>
              <%= ErrorHelpers.error_tag(f, :url, bind_to_input: false) %>
            </div>

            <%= live_component(@socket, KeyValueEditor, id: "step_#{@id}__key_value_editor_headers" <> @extract_step.id, css_label: "source-headers", form: f, field: :headers, target: "step-" <> @id) %>

          </div>
        </div>
      </form>
    </div>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> ExtractS3Step.changeset()
    |> complete_validation(socket)
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def handle_event("add", %{"field" => "headers"}, %{assigns: %{changeset: changeset}} = socket) do
    headers = Ecto.Changeset.get_field(changeset, :headers, [])
    new_header = ExtractHeader.changeset(%{})

    new_changes =
      changeset
      |> Ecto.Changeset.put_embed(:headers, headers ++ [new_header])

    {:noreply, assign(socket, changeset: new_changes)}
  end

  def handle_event("remove", %{"id" => header_id, "field" => "headers"}, socket) do
    updated_headers =
      socket.assigns.changeset
      |> Ecto.Changeset.get_field(:headers)
      |> remove_key_value(header_id)

    new_changset = Ecto.Changeset.put_embed(socket.assigns.changeset, :headers, updated_headers)

    {:noreply, assign(socket, changeset: new_changset)}
  end
end
