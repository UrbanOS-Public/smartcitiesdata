defmodule AndiWeb.EditLiveView.DataDictionaryRemoveFieldEditor do
  @moduledoc """
  LiveComponent for removing a field to a data dictionary
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Andi.InputSchemas.Datasets.DataDictionary
  alias Andi.InputSchemas.DataDictionaryFields

  def render(assigns) do
    id = Atom.to_string(assigns.id)

    modifier =
      if assigns.visible do
        "visible"
      else
        "hidden"
      end

    ~L"""
    <div id=<%= @id %> class="data-dictionary-remove-field-editor data-dictionary-remove-field-editor--<%= modifier %>">
      <div class="modal-form-container">
        <p>Are you sure you want to remove this field?</p>
        <br>

        <div class="button-container">
          <%= reset("CANCEL", phx_click: "cancel", phx_target: "##{id}", class: "btn") %>
          <%= submit("DELETE", phx_click: "remove_field", phx_target: "##{id}", class: "btn submit_button") %>
        </div>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, visible: false)}
  end

  def handle_event("remove_field", _, socket) do
    case DataDictionaryFields.remove_field(socket.assigns.selected_field_id) do
      {:ok, deleted_field} ->
        send(self(), {:remove_data_dictionary_field_succeeded})

      {:error, changeset} ->
        IO.inspect(changeset, label: "failed to delete")
        # Map.put(changeset, :action, :update)
    end

    {:noreply, assign(socket, visible: false)}
  end

  def handle_event("cancel", _, socket) do
    send(self(), {:remove_data_dictionary_field_cancelled})
    {:noreply, assign(socket, visible: false)}
  end

  defp blank_changeset() do
    DataDictionary.changeset(%DataDictionary{}, %{})
  end
end
