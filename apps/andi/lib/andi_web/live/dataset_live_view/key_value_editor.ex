defmodule AndiWeb.EditLiveView.KeyValueEditor do
  @moduledoc """
    LiveComponent for an nested key/value form
  """
  use Phoenix.LiveComponent
  import Phoenix.HTML.Form

  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.InputSchemas.KeyValueFormSchema
  alias Ecto.Changeset
  alias AndiWeb.ErrorHelpers

  def render(assigns) do
    ~L"""
    <div id="<%= @id %>" class="url-form__<%= @css_label %> url-form-table">
      <div class="url-form-table__title"><%= DisplayNames.get(@field) %></div>
      <table class="url-form-table__table" title='<%= DisplayNames.get(@field) %>' aria-label="<%= @id %>">
        <tr class="url-form-table__row url-form-table__row--bordered">
          <th class="url-form-table__cell url-form-table__cell--bordered url-form-table__cell--header">KEY</th>
          <th class="url-form-table__cell url-form-table__cell--bordered url-form-table__cell--header" colspan="2">VALUE</th>
        </tr>
        <%= inputs_for @form, @field, fn f -> %>
          <tr class="url-form-table__row url-form-table__row--bordered">
            <td class="url-form-table__cell url-form-table__cell--bordered">
              <%= text_input(f, :key, [class: "input full-width url-form__#{@css_label}-key-input"]) %>
            </td>
            <td class="url-form-table__cell url-form-table__cell--bordered">
              <%= text_input(f, :value, [class: "input full-width url-form__#{@css_label}-value-input"]) %>
            </td>
            <td class="url-form-table__cell url-form-table__cell--delete">
              <button type="button" class="url-form__<%= @css_label %>-delete-btn url-form-table__btn" phx-click="remove" phx-target="<%= @myself %>" phx-value-id="<%= input_value(f, :id) %>" phx-value-field="<%= @field %>">
                <img src="/images/remove.svg" alt="Remove"/>
              </button>
            </td>
          </tr>
        <% end %>
      </table>
      <button type="button" class="url-form__<%= @css_label %>-add-btn url-form-table__btn" phx-click="add" phx-target="<%= @myself %>" phx-value-field="<%= @field %>">
        <img src="/images/add.svg" alt="Add"/>
      </button>
      <%= ErrorHelpers.error_tag(@form, @field, bind_to_input: false) %>
    </div>
    """
  end

  def handle_event("add", _, socket) do
    new_field_changes = %{key: "", value: ""}

    new_changeset = KeyValueFormSchema.changeset(%KeyValueFormSchema{}, new_field_changes)

    new_changesets = socket.assigns.changesets ++ [new_changeset]

    socket.assigns.parent_module.update_key_value(socket.assigns.field, new_changesets, socket.assigns.parent_id)

    {:noreply, socket}
  end

  def handle_event("remove", %{"id" => id}, socket) do
    element_to_delete =
      Enum.find(socket.assigns.changesets, fn changeset ->
        changeset_id =
          case Changeset.fetch_field(changeset, :id) do
            {_, id} -> id
            :error -> nil
          end

        changeset_id == id
      end)

    new_changesets = List.delete(socket.assigns.changesets, element_to_delete)

    socket.assigns.parent_module.update_key_value(socket.assigns.field, new_changesets, socket.assigns.parent_id)

    {:noreply, socket}
  end
end
