defmodule AndiWeb.DataDictionary.RemoveFieldEditor do
  @moduledoc """
  LiveComponent for removing a field to a data dictionary
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

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

    show_warning_message? = is_parent_field?(assigns.selected_field) and assigns.requires_warning

    ~L"""
    <div id=<%= @id %> class="data-dictionary-remove-field-editor data-dictionary-remove-field-editor--<%= modifier %>">
      <div class="modal-form-container">
        <p class="data-dicitionary-remove-field-editor__message"><%= @modal_text %></p>

        <br>

        <div class="button-container">
          <%= reset("CANCEL", phx_click: "cancel", phx_target: "##{id}", class: "btn") %>
          <button class="btn submit_button" type="button" phx-click="remove_field" phx-target="<%= @myself %>" phx-value-parent="<%= show_warning_message? %>">DELETE</button>

        </div>

        <p class="error-msg data-dictionary-remove-field-editor__error-msg--<%= has_error_msg %>"><%= @error_msg %></p>
      </div>
    </div>
    """
  end

  def mount(socket) do
    {:ok,
     assign(socket,
       visible: false,
       error_msg: "",
       requires_warning: true,
       modal_text: "Are you sure you want to remove this field?"
     )}
  end

  def handle_event("remove_field", %{"parent" => "true"}, socket) do
    {:noreply,
     assign(socket,
       modal_text: "WARNING! Removing this field will also remove its children. Would you like to continue?",
       requires_warning: false
     )}
  end

  def handle_event("remove_field", %{"parent" => "false"}, socket) do
    selected_field = socket.assigns.selected_field
    selected_field_id = Ecto.Changeset.get_field(selected_field.source, :id)
    selected_field_index = parse_index(selected_field.index)
    selected_field_parent_id = get_parent_of_field(selected_field.source.changes)

    case DataDictionaryFields.remove_field(selected_field_id) do
      {:ok, _} ->
        send(self(), {:remove_data_dictionary_field_succeeded, selected_field_parent_id, selected_field_index})

        {:noreply,
         assign(socket,
           visible: false,
           error_msg: "",
           requires_warning: true,
           modal_text: "Are you sure you want to remove this field?"
         )}

      nil ->
        {:noreply, assign(socket, error_msg: "The selected field was not found in the database")}
    end
  end

  def handle_event("cancel", _, socket) do
    send(self(), {:remove_data_dictionary_field_cancelled})

    {:noreply,
     assign(socket,
       visible: false,
       requires_warning: true,
       error_msg: "",
       modal_text: "Are you sure you want to remove this field?"
     )}
  end

  defp is_parent_field?(:no_dictionary), do: false

  defp is_parent_field?(selected_field) do
    field_sub_schema = Ecto.Changeset.get_change(selected_field.source, :subSchema)

    field_sub_schema != nil and field_sub_schema != []
  end

  defp get_parent_of_field(%{parent_id: parent_id}), do: parent_id
  defp get_parent_of_field(%{technical_id: technical_id}), do: technical_id
  defp get_parent_of_field(_), do: {:error, "parent not found"}

  defp parse_index(index) when is_integer(index), do: index
  defp parse_index(index) when is_binary(index), do: String.to_integer(index)
  defp parse_index(index), do: index
end
