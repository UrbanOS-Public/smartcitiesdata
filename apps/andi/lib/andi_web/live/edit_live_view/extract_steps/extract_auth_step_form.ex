defmodule AndiWeb.ExtractSteps.ExtractAuthStepForm do
  @moduledoc """
  LiveComponent for an extract step with type AUTH
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML
  import Phoenix.HTML.Form
  import AndiWeb.Helpers.ExtractStepHelpers
  require Logger

  alias Andi.InputSchemas.Datasets.ExtractAuthStep
  alias Andi.InputSchemas.Datasets.ExtractHeader
  alias Andi.InputSchemas.Datasets.ExtractQueryParam
  alias AndiWeb.EditLiveView.KeyValueEditor
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.Helpers.FormTools
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

      <%= live_component(@socket, ExtractStepHeader, step_name: "Auth", step_id: @id) %>

      <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: "#step-#{@id}", as: :form_data] %>
        <% hidden_input(f, :body) %>

        <div class="component-edit-section--<%= @visibility %>">
          <div class="extract-auth-step-form-edit-section form-grid">

            <div class="extract-auth-step-form__destination">
              <%= label(f, :destination, DisplayNames.get(:destination),  class: "label label--required") %>
              <%= text_input(f, :destination, class: "input") %>
              <%= ErrorHelpers.error_tag(f, :destination, bind_to_input: false) %>
            </div>

            <div class="extract-auth-step-form__url">
              <%= label(f, :url, DisplayNames.get(:url), class: "label label--required") %>
              <%= text_input(f, :url, class: "input full-width") %>
              <%= ErrorHelpers.error_tag(f, :url, bind_to_input: false) %>
            </div>

            <div class="extract-auth-step-form__body">
              <%= label(f, :body, DisplayNames.get(:body),  class: "label") %>
              <%= textarea(f, :body, class: "input full-width", phx_hook: "prettify") %>
              <%= ErrorHelpers.error_tag(f, :body, bind_to_input: false) %>
            </div>

            <%= live_component(@socket, KeyValueEditor, id: "key_value_editor_headers" <> @extract_step.id, css_label: "source-headers", form: f, field: :headers, target: "step-" <> @id) %>

            <div class="extract-auth-step-form__path">
              <%= label(f, :path, DisplayNames.get(:path),  class: "label label--required") %>
              <% form_path = input_value(f, :path) %>
              <%= text_input(f, :path, class: "input", value: path_to_string(form_path)) %>
              <%= ErrorHelpers.error_tag(f, :path, bind_to_input: false) %>
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

  defp remove_key_value(key_value_list, id) do
    Enum.reduce_while(key_value_list, key_value_list, fn key_value, acc ->
      case key_value.id == id do
        true -> {:halt, List.delete(key_value_list, key_value)}
        false -> {:cont, acc}
      end
    end)
  end

  defp key_values_to_keyword_list(form_data, field) do
    form_data
    |> Map.get(field, [])
    |> Enum.map(fn %{key: key, value: value} -> {key, value} end)
  end

  defp path_to_string(nil), do: nil
  defp path_to_string(path_array), do: Enum.join(path_array, ".")
end
