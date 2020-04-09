defmodule AndiWeb.EditLiveView.DataDictionaryAddFieldEditor do
  @moduledoc """
    LiveComponent for adding a field to a data dictionary
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form
  import AndiWeb.ErrorHelpers
  import Ecto.Query, only: [from: 2]

  alias Andi.InputSchemas.Options
  alias Andi.InputSchemas.StructTools
  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Datasets.DataDictionary

  def mount(socket) do
    changeset = DataDictionary.changeset(%DataDictionary{}, %{})

    {:ok, assign(socket, expansion_map: %{}, selected_field_id: :unassigned, changeset: changeset)}
  end

  def render(assigns) do
    id = Atom.to_string(assigns.id)

    ~L"""
    <div class="data-dictionary-add-field-editor" >
    <%= form = form_for @changeset, "#", [phx_submit: "add_field", id: @id, phx_target: "##{id}", as: :field] %>
        <div>
          <%= label(form, :name, "Name", class: "label label--required") %>
          <%= text_input(form, :name, id: id <> "_name", class: "input") %>
          <%= error_tag(form, :name) %>
        </div>
        <div>
          <%= label(form, :type, "Type", class: "label label--required") %>
          <%= select(form, :type, [{:cam, "ajsf"}], id: id <> "_type", class: "select") %>
        </div>
        <div>
          <%= label(form, :parent_id, "Child Of", class: "label") %>
          <%= select(form, :parent_id, [{:laksn, "a58ed8fc-4e9f-4839-8393-6ebdbda29db4"}],  id: id <> "_child-of", class: "select") %>
        </div>

        <div>
          <button class="btn btn--large">Cancel</button>
          <%= submit("Add Field", id: "add_field_button", class: "btn btn--large") %>
        </div>
       </form>
      </div>
    """
  end

  def handle_event("add_field", %{"field" => %{"name" => name, "type" => type, "parent_id" => parent} = field}, socket) do
    field_as_atomic_map = AtomicMap.convert(field, safe: false)
    changeset = DataDictionary.changeset_with_parent_id(%DataDictionary{}, field_as_atomic_map) |> IO.inspect(label: "changeset")

    if changeset.valid? do
      {:ok, data_dictionary} = Andi.Repo.insert_or_update(changeset)
      send(self(), {:new_dictionary_field_added, data_dictionary.id})
    end

    new_changeset = Map.put(changeset, :action, :update)
    {:noreply, assign(socket, changeset: new_changeset)}
  end

  def get_parent_ids(dataset) do
    dataset
    |> StructTools.to_map()
    |> get_in([:technical, :schema])
    |> get_child_ids([])
    |> Enum.reverse()
  end

  defp get_child_ids(nil, id_list, _), do: id_list
  defp get_child_ids(parent, id_list, parent_bread_crumb \\ "") do
    Enum.reduce(parent, id_list, fn schema_field, acc ->
      case schema_field.type do
        item when item in ["map", "list"] ->
          child_bread_crumb = parent_bread_crumb <> schema_field.name
          acc = [{schema_field.id, child_bread_crumb} | acc]
          get_child_ids(schema_field[:subSchema], acc, child_bread_crumb <> " > ")
        _ -> acc
      end
    end)
  end
end
