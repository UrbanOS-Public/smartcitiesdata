defmodule AndiWeb.EditLiveView.DataDictionaryAddFieldEditor do
  @moduledoc """
    LiveComponent for adding a field to a data dictionary
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias Andi.InputSchemas.Options

  def mount(socket) do
    {:ok, assign(socket, expansion_map: %{}, selected_field_id: :unassigned)}
  end

  def render(assigns) do
    id = Atom.to_string(assigns.id)

    ~L"""
      <div id="<%= @id %>" class="data-dictionary-add-field-editor" >
      </div>
    """
  end
end
