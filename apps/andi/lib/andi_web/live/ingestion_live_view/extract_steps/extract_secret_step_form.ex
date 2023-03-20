defmodule AndiWeb.ExtractSteps.ExtractSecretStepForm do
  @moduledoc """
  LiveComponent for an extract step with type Secret
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  require Logger

  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.DisplayNames
  alias Ecto.Changeset
  alias Andi.InputSchemas.Ingestions.ExtractSecretStep

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
      <%= f = form_for @changeset, "#", [phx_change: :validate, phx_target: @myself, as: :form_data, phx_submit: :save_secret, id: @id] %>

        <div class="component-edit-section--<%= @visibility %>">
          <div class="extract-secret-step-form-edit-section form-grid">
            <div class="extract-secret-step-form__destination">
              <%= label(f, :destination, DisplayNames.get(:destination), class: "label label--required", for: "#{@id}_secret_destination") %>
              <%= text_input(f, :destination, [id: "#{@id}_secret_destination", class: "extract-secret-step-form__destination input", required: true, aria_label: "Secret #{DisplayNames.get(:destination)}"]) %>
              <%= ErrorHelpers.error_tag(f, :destination, id: "#{@id}_secret_destination_error") %>
            </div>

            <div class="extract-secret-step-form__value">
              <%= label(f, :secret_value, DisplayNames.get(:secret_value), class: "label label--required", for: "#{@id}_secret_value") %>
              <%= text_input(f, :secret_value, [id: "#{@id}_secret_value", type: "password", class: "extract-secret-step-form__secret-value input", placeholder: "Secrets are not displayed after being saved", required: true]) %>
              <% class = get_add_button_class(@changeset) %>
              <button type="submit" class="btn btn--action <%= class %>" aria-label="Add Secret Value">Add</button>
              <span class="secret__status-msg <%= save_success_class(@save_success) %>"><%= @save_secret_message %></span>
            </div>
          </div>
        </div>
      </form>
    """
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    updated_form_data =
      form_data
      |> update_key(socket.assigns.id)
      |> update_sub_key()

    extract_step = ExtractSecretStep.changeset(socket.assigns.changeset, updated_form_data)

    AndiWeb.IngestionLiveView.ExtractSteps.ExtractStepForm.update_extract_step(extract_step, socket.assigns.id)

    {:noreply, socket}
  end

  def handle_event("validate", _, socket) do
    send(socket.parent_pid, :page_error)

    {:noreply, socket}
  end

  def handle_event("save_secret", %{"form_data" => %{"secret_value" => secret_value} = _form_data} = _assigns, socket) do
    key =
      case Changeset.fetch_field(socket.assigns.changeset, :sub_key) do
        {_, key} -> key
        :error -> ""
      end

    path =
      case Changeset.fetch_field(socket.assigns.changeset, :key) do
        {_, path} -> path
        :error -> ""
      end

    case Andi.SecretService.write(path, %{key => secret_value}) do
      {:ok, _} ->
        {:noreply, assign(socket, save_success: true, save_secret_message: "Secret saved successfully!")}

      {:error, _} ->
        {:noreply, assign(socket, save_success: false, save_secret_message: "Secret save failed, contact your system administrator.")}
    end
  end

  defp update_key(%{"destination" => destination} = form_data, id), do: Map.put(form_data, "key", "#{id}___#{destination}")

  defp update_sub_key(%{"destination" => destination} = form_data), do: Map.put(form_data, "sub_key", destination)

  defp save_success_class(true), do: "secret__save-success"
  defp save_success_class(false), do: "secret__save-fail"

  defp get_add_button_class(changeset) do
    case changeset.valid? do
      true -> "btn--action"
      false -> "btn--disabled"
    end
  end
end
