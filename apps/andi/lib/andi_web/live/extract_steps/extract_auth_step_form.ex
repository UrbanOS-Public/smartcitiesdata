defmodule AndiWeb.ExtractSteps.ExtractAuthStepForm do
  @moduledoc """
  LiveComponent for an extract step with type AUTH
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import AndiWeb.Helpers.ExtractStepHelpers
  require Logger

  alias Andi.InputSchemas.Ingestions.ExtractAuthStep
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
    <div id="step-<%= @id %>" class="extract-step-container extract-auth-step-form">

      <%= live_component(@socket, ExtractStepHeader, step_name: "Authorization", step_id: @id) %>

      <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: "#step-#{@id}", as: :form_data] %>
        <% hidden_input(f, :body) %>

        <div class="component-edit-section--<%= @visibility %>">
          <div class="extract-auth-step-form-edit-section form-grid">

            <div class="extract-auth-step-form__destination">
              <%= label(f, :destination, DisplayNames.get(:destination),  class: "label label--required") %>
              <%= text_input(f, :destination, [id: "step_#{@id}__auth_destination", class: "input", required: true]) %>
              <%= ErrorHelpers.error_tag(f, :destination, bind_to_input: false) %>
            </div>

            <div class="extract-auth-step-form__url">
              <%= label(f, :url, DisplayNames.get(:url), class: "label label--required") %>
              <%= text_input(f, :url, [id: "step_#{@id}__auth_url", class: "input full-width", required: true]) %>
              <%= ErrorHelpers.error_tag(f, :url, bind_to_input: false) %>
            </div>

            <%= live_component(@socket, KeyValueEditor, id: "step_#{@id}__key_value_editor_headers" <> @extract_step.id, css_label: "source-headers", form: f, field: :headers, target: "step-" <> @id) %>

            <div class="extract-auth-step-form__body">
              <%= label(f, :body, DisplayNames.get(:body),  class: "label") %>
              <%= textarea(f, :body, id: "step_#{@id}__auth_url", class: "input full-width", phx_hook: "prettify") %>
              <%= ErrorHelpers.error_tag(f, :body, bind_to_input: false) %>
            </div>

            <div class="extract-auth-step-form__path">
              <%= label(f, :path, DisplayNames.get(:path),  class: "label label--required") %>
              <% form_path = input_value(f, :path) %>
              <%= text_input(f, :path, [id: "step_#{@id}__auth_path", class: "input", value: path_to_string(form_path), required: true]) %>
              <span class="input__help-text">Separate response path keys with a period (.) (e.g. 'data.token' for response {"data": {"token": "abc123"}}) </span>
              <%= ErrorHelpers.error_tag(f, :path, bind_to_input: false) %>
            </div>

            <div class="extract-auth-step-form__cacheTtl">
              <%= label(f, :cacheTtl, DisplayNames.get(:cacheTtl),  class: "label label--required") %>
              <% form_ttl = input_value(f, :cacheTtl) %>
              <%= text_input(f, :cacheTtl, [id: "step_#{@id}__auth_cache_ttl", class: "input", value: milliseconds_to_minutes(form_ttl), required: true]) %>
              <span class="input__help-text">Time in minutes that credentials are stored (defaults to 15 minutes)</span>
              <%= ErrorHelpers.error_tag(f, :cacheTtl, bind_to_input: false) %>
            </div>

          </div>
        </div>
      </form>
    </div>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> Map.update(:path, "", &String.split(&1, "."))
    |> convert_form_cache_ttl()
    |> ExtractAuthStep.changeset()
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

  defp path_to_string(empty_path) when empty_path in [nil, ""], do: empty_path
  defp path_to_string(path_array), do: Enum.join(path_array, ".")

  defp milliseconds_to_minutes(milliseconds) when milliseconds in [nil, ""], do: milliseconds
  defp milliseconds_to_minutes(milliseconds) when is_integer(milliseconds), do: div(milliseconds, 60_000)
  defp milliseconds_to_minutes(milliseconds), do: milliseconds

  defp convert_form_cache_ttl(%{cacheTtl: nil}), do: nil

  defp convert_form_cache_ttl(%{cacheTtl: form_cache_ttl} = form_data) do
    case String.match?(form_cache_ttl, ~r/^[[:digit:]]+$/) do
      true -> Map.put(form_data, :cacheTtl, String.to_integer(form_cache_ttl) * 60_000)
      false -> form_data
    end
  end

  defp convert_form_cache_ttl(form_data), do: form_data
end
