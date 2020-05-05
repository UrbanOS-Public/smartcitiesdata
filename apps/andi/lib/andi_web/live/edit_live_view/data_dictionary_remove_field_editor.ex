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

    has_error_msg =
    if assigns.error_msg != "" do
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

        <p class="error-msg data-dictionary-remove-field-editor__error-msg--<% has_error_msg %>"><%= @error_msg %></p>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, visible: false, error_msg: "")}
  end

  def handle_event("remove_field", _, socket) do
    selected_field = socket.assigns.selected_field
    selected_field_id = Ecto.Changeset.get_field(selected_field.source, :id)
    selected_field_index = selected_field.index
    selected_field_parent_id = get_parent_of_field(selected_field.source.changes)

    case DataDictionaryFields.remove_field(selected_field_id) do
      {:ok, deleted_field} ->
        send(self(), {:remove_data_dictionary_field_succeeded, selected_field_parent_id, selected_field_index})
        {:noreply, assign(socket, visible: false)}

      nil ->
        IO.inspect("failed to delete")
        {:noreply, assign(socket, error_msg: "The selected field was not found in the database")}
    end

  end

  def handle_event("cancel", _, socket) do
    send(self(), {:remove_data_dictionary_field_cancelled})
    {:noreply, assign(socket, visible: false)}
  end

  defp get_parent_of_field(%{parent_id: parent_id} = field), do: parent_id
  defp get_parent_of_field(%{technical_id: technical_id} = field), do: technical_id
  defp get_parent_of_field(_), do: {:error, "parent not found"}
end
