defmodule AndiWeb.ExtractSteps.ExtractAuthStepForm do
  @moduledoc """
  LiveComponent for an extract step with type AUTH
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  require Logger

  alias Andi.InputSchemas.Ingestions.ExtractAuthStep
  alias Ecto.Changeset
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.DisplayNames
  alias Andi.InputSchemas.StructTools

  def mount(socket) do
    {:ok,
     assign(socket,
       visibility: "expanded"
     )}
  end

  def render(assigns) do
    header_changesets =
      case Changeset.fetch_change(assigns.changeset, :headers) do
        {_, header_changesets} -> header_changesets
        :error -> []
      end

    ~L"""
    <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: @myself, as: :form_data, id: @id] %>

      <div class="component-edit-section--<%= @visibility %>">
        <div class="extract-auth-step-form-edit-section form-grid">
          <div class="extract-auth-step-form__destination">
            <%= label(f, :destination, DisplayNames.get(:destination), class: "label label--required", for: "#{@id}_auth_destination") %>
            <%= text_input(f, :destination, [class: "input", required: true, id: "#{@id}_auth_destination", aria_label: "Auth #{DisplayNames.get(:destination)}"]) %>
            <%= ErrorHelpers.error_tag(f, :destination, bind_to_input: false, id: "#{@id}_auth_destination_error") %>
          </div>

          <div class="extract-auth-step-form__url">
            <%= label(f, :url, DisplayNames.get(:url), class: "label label--required", for: "#{@id}_auth_url") %>
            <%= text_input(f, :url, [class: "input full-width", required: true, id: "#{@id}_auth_url", aria_label: "Auth #{DisplayNames.get(:url)}"]) %>
            <%= ErrorHelpers.error_tag(f, :url, bind_to_input: false, id: "#{@id}_auth_url_error") %>
          </div>

          <%= live_component(KeyValueEditor, id: "#{@id}__key_pvalue_editor_headers", css_label: "source-headers", form: f, field: :headers, parent_id: @id, changesets: header_changesets, parent_module: __MODULE__) %>

          <div class="extract-auth-step-form__body">
            <%= label(f, :body, DisplayNames.get(:body), class: "label", for: "#{@id}_auth_body") %>
            <%= textarea(f, :body, [class: "input full-width", phx_hook: "prettify", id: "#{@id}_auth_body", aria_label: "Auth #{DisplayNames.get(:body)}"]) %>
            <%= ErrorHelpers.error_tag(f, :body, bind_to_input: false, id: "#{@id}_auth_body_error") %>
          </div>

          <div class="extract-auth-step-form__path">
            <%= label(f, :path, DisplayNames.get(:path), class: "label", for: "#{@id}_auth_path") %>
            <%= text_input(f, :path, [class: "input", value: path_to_string(input_value(f, :path)), required: true, id: "#{@id}_auth_path", aria_label: "Auth #{DisplayNames.get(:path)}"]) %>
            <span class="input__help-text">Separate response path keys with a period (.) (e.g. 'data.token' for response {"data": {"token": "abc123"}}) </span>
            <%= ErrorHelpers.error_tag(f, :path, bind_to_input: false, id: "#{@id}_auth_path_error") %>
          </div>

          <div class="extract-auth-step-form__cacheTtl">
            <%= label(f, :cacheTtl, DisplayNames.get(:cacheTtl), class: "label", for: "#{@id}_auth_cacheTtl") %>
            <%= text_input(f, :cacheTtl, [class: "input", value: milliseconds_to_minutes(input_value(f, :cacheTtl)), required: true, id: "#{@id}_auth_cacheTtl", aria_label: "Auth #{DisplayNames.get(:cacheTtl)}"]) %>
            <span class="input__help-text">Time in minutes that credentials are stored (defaults to 15 minutes)</span>
            <%= ErrorHelpers.error_tag(f, :cacheTtl, bind_to_input: false, id: "#{@id}_auth_cacheTtl_error") %>
          </div>
        </div>
      </div>
    </form>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data = form_data
      |> sort_map_to_list("headers")
    extract_step = ExtractAuthStep.changeset(socket.assigns.changeset, form_data)

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
    applied_changes =
      Enum.map(changesets, fn changeset ->
        Changeset.apply_changes(changeset)
        |> StructTools.to_map()
      end)

    changes = %{field => applied_changes}

    extract_step =
      socket.assigns.changeset
      |> Changeset.delete_change(field)
      |> ExtractAuthStep.changeset(changes)

    AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm.update_extract_step(extract_step, socket.assigns.id)

    {:ok, socket}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  defp sort_map_to_list(form_data, value) do
    updated_list = form_data
      |> Map.get(value, [])
      |> Enum.reduce([], fn {key, value}, acc ->
        int_key = String.to_integer(key)
        List.insert_at(acc, int_key, value)
      end)

    Map.put(form_data, value, updated_list)
  end

  defp path_to_string(empty_path) when empty_path in [nil, ""], do: empty_path
  defp path_to_string(path_array), do: Enum.join(path_array, ".")

  defp milliseconds_to_minutes(milliseconds) when milliseconds in [nil, ""], do: milliseconds
  defp milliseconds_to_minutes(milliseconds) when is_integer(milliseconds), do: div(milliseconds, 60_000)
  defp milliseconds_to_minutes(milliseconds), do: milliseconds
end
