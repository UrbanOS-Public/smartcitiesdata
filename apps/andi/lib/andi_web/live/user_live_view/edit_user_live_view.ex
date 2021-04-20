defmodule AndiWeb.UserLiveView.EditUserLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  import Phoenix.HTML.Form
  import SmartCity.Event, only: [organization_update: 0, dataset_delete: 0]

  alias Andi.Schemas.User
  alias Andi.Services.Auth0Management

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
      <div id="edit-user-live-view" class="user-edit-page edit-page">
          <div class="edit-user-title">
              <h2 class="component-title-text">Edit User </h2>
          </div>

          <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data] %>
              <div class="user-form__email">
                  <%= label(f, :email, class: "label label--required") %>
                  <%= text_input(f, :email, class: "input", readonly: true) %>
              </div>
              <div class="user-form__role">
                  <%= label(f, :user_role, class: "label") %>
                  <%= select(f, :user_role, @roles, [class: "select", readonly: true]) %>
              </div>
          </form>

          <div class="associated-organizations-table">
            <h3>Organizations Associated With This User</h3>

            <%= live_component(@socket, AndiWeb.EditUserLiveView.EditUserLiveViewTable, organizations: @organizations) %>
          </div>
      </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "user" => user}, socket) do
    changeset = User.changeset(user, %{}) |> Map.put(:errors, [])

    case Auth0Management.get_roles() do
      roles ->
        roles = roles |> Enum.map(fn %{"name" => name, "description" => description} -> {description, name} end)
        {:ok, assign(socket, is_curator: is_curator, changeset: changeset, roles: roles, organizations: user.organizations)}

      {:error, error} ->
        {:ok, assign(socket, is_curator: is_curator, changeset: changeset, roles: [], page_error: true, organizations: [])}
    end
  end

  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end
end
