defmodule AndiWeb.UserLiveView.EditUserLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  import Phoenix.HTML.Form
  import SmartCity.Event, only: [organization_update: 0, dataset_delete: 0, user_organization_associate: 0]

  alias SmartCity.UserOrganizationAssociate
  alias Andi.Schemas.User
  alias Andi.Services.Auth0Management
  alias AndiWeb.Helpers.MetadataFormHelpers

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
      <div id="edit-user-live-view" class="user-edit-page edit-page">
          <div class="edit-user-title">
              <h2 class="component-title-text">Edit User </h2>
          </div>

          <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data, phx_submit: :associate] %>
              <div class="user-form__email">
                  <%= label(f, :email, class: "label label--required") %>
                  <%= text_input(f, :email, class: "input", readonly: true) %>
              </div>
              <div class="user-form__role">
                  <%= label(f, :user_role, class: "label") %>
                  <%= select(f, :user_role, @roles, [class: "select", readonly: true]) %>
              </div>

              <div class="user-form__organizations">
                <%= label(:organization, :org_id, class: "label") %>
                <%= select(:organiation, :org_id, MetadataFormHelpers.get_org_options(), [class: "select", readonly: true]) %>
                <button type="submit" class="btn btn--add-organization">Add Organization</button>
              </div>
          </form>

          <div id="edit-page-snackbar" phx-hook="showSnackbar">
            <div style="display: none;"><%= @click_id %></div>
            <%= if @success do %>
              <div id="snackbar" class="success-message">Organization successfully associated. Please refresh you see the updated organization.</div>
            <% end %>
          </div>

          <div class="associated-organizations-table">
            <h3>Organizations Associated With This User</h3>
            <%= live_component(@socket, AndiWeb.EditUserLiveView.EditUserLiveViewTable, organizations: @organizations, id: :edit_user_organizations) %>
          </div>
      </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "user" => user}, socket) do
    changeset = User.changeset(user, %{}) |> Map.put(:errors, [])

    case Auth0Management.get_roles() do
      roles ->
        roles = roles |> Enum.map(fn %{"name" => name, "description" => description} -> {description, name} end)

        {:ok,
         assign(socket,
           is_curator: is_curator,
           changeset: changeset,
           roles: roles,
           organizations: user.organizations,
           user: user,
           success: false,
           click_id: nil
         )}

      {:error, error} ->
        {:ok,
         assign(socket,
           is_curator: is_curator,
           changeset: changeset,
           roles: [],
           page_error: true,
           organizations: [],
           user: user,
           success: false,
           click_id: nil
         )}
    end
  end

  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def handle_event("associate", %{"organiation" => %{"org_id" => ""}}, socket) do
    {:noreply, socket}
  end

  def handle_event("associate", %{"organiation" => %{"org_id" => org_id}}, socket) do
    user = socket.assigns.user
    send_event(org_id, user)

    {:noreply, assign(socket, success: true, click_id: UUID.uuid4())}
  end

  def handle_event("associate", _, socket) do
    {:noreply, socket}
  end

  def handle_info({:disassociate_org, org_id}, socket) do
    IO.inspect(org_id, label: "handle this from the parent: ")
    {:noreply, socket}
  end

  defp send_event(org_id, user) do
    {:ok, event_data} = UserOrganizationAssociate.new(%{subject_id: user.subject_id, org_id: org_id, email: user.email})
    Brook.Event.send(:andi, user_organization_associate(), :andi, event_data)
  end
end
