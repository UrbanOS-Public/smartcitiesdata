defmodule AndiWeb.ExtractSteps.ExtractSecretStepForm do
  @moduledoc """
  LiveComponent for an extract step with type Secret
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import AndiWeb.Helpers.ExtractStepHelpers
  require Logger

  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.Options
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
    <div id="step-<%= @id %>" class="extract-step-container extract-secret-step-form">

        <%= live_component(@socket, ExtractStepHeader, step_name: "Secret", step_id: @id) %>

        <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: "#step-#{@id}", as: :form_data] %>
          <%= hidden_input(f, :id) %>
          <%= hidden_input(f, :type) %>
          <%= hidden_input(f, :technical_id) %>

          <div class="component-edit-section--<%= @visibility %>">
            <div class="extract-secret-step-form-edit-section form-grid">

              <div class="extract-secret-step-form__destination">
                <%= label(f, :destination, DisplayNames.get(:destination), class: "label label--required") %>
                <%= text_input(f, :destination, id: "date_destination", class: "extract-secret-step-form__destination input", phx_target: "#step-#{@id}") %>
                <%= ErrorHelpers.error_tag(f, :destination) %>
              </div>

              <div class="extract-secret-step-form__name">
                <%= label(f, :sub_key, DisplayNames.get(:sub_key), class: "label label--required") %>
                <%= text_input(f, :sub_key, class: "extract-secret-step-form__name input", phx_target: "#step-#{@id}") %>
                <%= ErrorHelpers.error_tag(f, :sub_key) %>
              </div>

              <div class="extract-secret-step-form__value">
                <%= label(f, :secret_value, DisplayNames.get(:secret_value), class: "label label--required") %>
                <div class="secret_value_add">
                  <%= text_input(f, :secret_value, type: "password", class: "extract-secret-step-form__secret-value input", phx_target: "#step-#{@id}") %>
                  <button type="button" class="btn btn--action">Add</button>
                </div>
              </div>
            </div>
          </div>
        </form>
      </div>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    # {updated_changeset, updated_socket} =
    #   form_data
    #   |> AtomicMap.convert(safe: false, underscore: false)
    #   |> ExtractDateStep.changeset()
    #   |> update_example_output(socket)

    # complete_validation(updated_changeset, updated_socket)

    {:noreply, socket}
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end
end
