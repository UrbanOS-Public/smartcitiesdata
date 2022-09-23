defmodule AndiWeb.ExtractSteps.ExtractSecretStepForm do
  @moduledoc """
  LiveComponent for an extract step with type Secret
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import AndiWeb.Helpers.ExtractStepHelpers
  require Logger

  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.ExtractSteps.ExtractStepHeader
  alias Andi.InputSchemas.Ingestions.ExtractSecretStep
  alias Phoenix.HTML.FormData

  def mount(socket) do
    {:ok,
     assign(socket,
       visibility: "expanded",
       validation_status: "collapsed",
       save_secret_message: "",
       save_success: true
     )}
  end

  def render(assigns) do
    ~L"""
    <div id="step-<%= @id %>" class="extract-step-container extract-secret-step-form">

        <%= live_component(@socket, ExtractStepHeader, step_name: "Secret", step_id: @id) %>

        <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: "#step-#{@id}", as: :form_data] %>
          <%= hidden_input(f, :key) %>

          <div class="component-edit-section--<%= @visibility %>">
            <div class="extract-secret-step-form-edit-section form-grid">

              <div class="extract-secret-step-form__destination">
                <%= label(f, :destination, DisplayNames.get(:destination), class: "label label--required") %>
                <%= text_input(f, :destination, [id: "step_#{@id}__secret_destination", class: "extract-secret-step-form__destination input", phx_target: "#step-#{@id}", required: true]) %>
                <%= ErrorHelpers.error_tag(f, :destination) %>
              </div>

              <div class="extract-secret-step-form__value">
                <%= label(f, :secret_value, DisplayNames.get(:secret_value), class: "label label--required") %>
                <div class="secret_value_add">
                  <%= text_input(f, :secret_value, [id: "step_#{@id}__secret_destination", type: "password", class: "extract-secret-step-form__secret-value input", phx_target: "#step-#{@id}", placeholder: "Secrets are not displayed after being saved", required: true]) %>
                  <% secret_value = FormData.input_value(nil, f, :secret_value) %>
                  <button type="button" class="btn btn--action" phx-click="save_secret" <%= disable_add_button(@changeset, secret_value) %> phx-target='<%="#step-#{@id}"%>' phx-value-secret="<%= secret_value %>">Add</button>
                  <span class="secret__status-msg <%= save_success_class(@save_success) %>"><%= @save_secret_message %></span>
                </div>
              </div>
            </div>
          </div>
        </form>
      </div>
    """
  end

  def handle_event("validate", %{"form_data" => %{"destination" => destination} = form_data}, socket) do
    form_data
    |> AtomicMap.convert(safe: false, underscore: false)
    |> Map.put(:sub_key, destination)
    |> Map.put(:key, "#{socket.assigns.extract_step.id}___#{destination}")
    |> ExtractSecretStep.changeset()
    |> complete_validation(socket)
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def handle_event("save_secret", %{"secret" => secret}, socket) do
    key = socket.assigns.changeset.changes.sub_key
    path = socket.assigns.changeset.changes.key

    case Andi.SecretService.write(path, %{key => secret}) do
      {:ok, _} ->
        {:noreply, assign(socket, save_success: true, save_secret_message: "Secret saved successfully!")}

      {:error, _} ->
        {:noreply, assign(socket, save_success: false, save_secret_message: "Secret save failed, contact your system administrator.")}
    end
  end

  defp save_success_class(true), do: "secret__save-success"
  defp save_success_class(false), do: "secret__save-fail"

  defp disable_add_button(_, secret_value) when secret_value in [nil, ""], do: "disabled"
  defp disable_add_button(%{valid?: false}, _), do: "disabled"
  defp disable_add_button(_, _), do: ""
end
