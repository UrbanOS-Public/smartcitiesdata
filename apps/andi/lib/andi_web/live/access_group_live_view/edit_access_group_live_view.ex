defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  import Phoenix.HTML.Form

  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.AccessGroups

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-page" id="access-groups-edit-page edit-page">
      <div class="edit-access-group-title">
        <h2 class="component-title-text">Edit Access Group </h2>
      </div>

      <%= form = form_for @changeset, "#", [as: :form_data, phx_change: :form_change] %>
      <%= hidden_input(form, :id) %>
      <%= hidden_input(form, :description) %>

        <div class="access-group-form__name">
          <%= label(form, :name, class: "label label--required") do "Access Group Name" end %>
          <%= text_input(form, :name, class: "input") %>
        </div>
      </form>

      <div class="edit-button-group">
        <div class="edit-button-group__cancel-btn">
          <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
        </div>
        <div class="edit-button-group__save-btn">
          <button type="submit" id="save-button" name="save-button" phx-click="form_save" class="btn btn--action btn--large">Save</button>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "access_group" => access_group} = _session, socket) do
    default_changeset = AccessGroup.changeset(access_group, %{}) |> Map.put(:errors, [])

    {:ok,
     assign(socket,
       is_curator: is_curator,
       access_group: access_group,
       changeset: default_changeset
     )}
  end

  def handle_event("cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: header_access_groups_path())}
  end

  def handle_event("form_save", _, socket) do
    case socket.assigns.changeset |> Ecto.Changeset.apply_changes() |> AccessGroups.update() do
      {:ok, _} ->
        {:noreply, redirect(socket, to: header_access_groups_path())}

      error ->
        Logger.warn("Unable to save Access Groups changes: #{inspect(error)}")
        {:noreply, socket}
    end
  end

  def handle_event("form_change", %{"form_data" => form_data}, socket) do
    new_changeset = form_data |> AccessGroup.changeset()
    {:noreply, assign(socket, changeset: new_changeset)}
  end
end
