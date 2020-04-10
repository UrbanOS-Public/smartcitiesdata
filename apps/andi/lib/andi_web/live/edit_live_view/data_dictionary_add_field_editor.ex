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
          <%= select(form, :parent_id, @eligible_parents.parent_ids,  id: id <> "_child-of", class: "select") %>
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
    |> IO.inspect(label: "field")


    # set parent_id to what was in the dropdopwn value
    # set technical_id to waht wasin dropdown value
    changeset = DataDictionary.changeset_with_parent_id(%DataDictionary{}, field_as_atomic_map) |> IO.inspect(label: "changeset")

    # if changeset.valid? do
    #   {:ok, data_dictionary} = Andi.Repo.insert_or_update(changeset)
    #   send(self(), {:new_dictionary_field_added, data_dictionary.id})
    # end

    new_changeset = Map.put(changeset, :action, :update)
    {:noreply, assign(socket, changeset: new_changeset)}
  end


  defp get_child_ids(nil, id_list, _), do: id_list
  defp get_child_ids(parent, id_list, parent_bread_crumb \\ "") do
    parent
    |> Enum.map(fn field ->
      field.type
    end)
    |> IO.inspect(label: "WTF")

    Enum.reduce(parent, id_list, fn schema_field, acc ->
      IO.inspect(schema_field.type, label: "evalutating")
      case schema_field.type do
        item when item in ["map", "list"] ->
          IO.inspect(item, label: "not skipping")
          child_bread_crumb = parent_bread_crumb <> schema_field.name
          acc = [{child_bread_crumb, schema_field.id} | acc]
          get_child_ids(schema_field[:subSchema], acc, child_bread_crumb <> " > ")
        type ->
          IO.inspect(type, label: "skipping")
          acc
      end
    end)
  end
end
