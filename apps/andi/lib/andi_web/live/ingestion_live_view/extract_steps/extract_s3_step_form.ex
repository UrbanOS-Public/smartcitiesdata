defmodule AndiWeb.ExtractSteps.ExtractS3StepForm do
  @moduledoc """
  LiveComponent for an extract step with type s3
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Ingestions.ExtractS3Step
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.DisplayNames
  alias Ecto.Changeset
  alias Andi.InputSchemas.StructTools

  def mount(socket) do
    {:ok,
     assign(socket,
       visibility: "expanded",
       validation_status: "collapsed"
     )}
  end

  def render(assigns) do
    header_changesets = case Changeset.fetch_change(assigns.changeset, :headers) do
      {_, header_changesets} -> header_changesets
      :error -> []
    end
    ~L"""
    <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: @myself, as: :form_data] %>
      <div class="component-edit-section--<%= @visibility %>">
        <div class="extract-s3-step-form-edit-section form-grid">
          <div class="extract-s3-step-form__url">
            <%= label(f, :url, DisplayNames.get(:url), class: "label label--required", for: "#{@id}__s3_url") %>
            <%= text_input(f, :url, [id: "#{@id}__s3_url", class: "input full-width", required: true]) %>
            <%= ErrorHelpers.error_tag(f, :url, bind_to_input: false) %>
          </div>

          <%= live_component(@socket, KeyValueEditor, id: "#{@id}__key_pvalue_editor_headers", css_label: "source-headers", form: f, field: :headers, parent_id: @id, changesets: header_changesets, parent_module: __MODULE__) %>
        </div>
      </div>
    </form>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    extract_step = ExtractS3Step.changeset(socket.assigns.changeset, form_data)

    AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm.update_extract_step(extract_step, socket.assigns.id)

    {:noreply, socket}
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def update_key_value(field, changesets, id) do
    send_update(__MODULE__, id: id, field: field, changesets: changesets)
  end

  def update(%{field: field, changesets: changesets}, socket) do
    applied_changes = Enum.map(changesets, fn changeset ->
      Changeset.apply_changes(changeset)
        |> StructTools.to_map()
    end)
    changes = %{field => applied_changes}

    extract_step = socket.assigns.changeset
      |> Changeset.delete_change(field)
      |>  ExtractS3Step.changeset(changes)

    AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm.update_extract_step(extract_step, socket.assigns.id)

    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end
end
