defmodule AndiWeb.UserLiveView.EditUserLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  import Phoenix.HTML.Form

  import SmartCity.Event,
    only: [organization_update: 0, dataset_delete: 0, user_organization_associate: 0, user_organization_disassociate: 0]

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
                  <%= label(f, :role, class: "label") %>
                  <%= select(f, :role, @roles, [class: "select", readonly: true, prompt: "Please select a role"]) %>
                  <button class="btn btn--add-organization" phx-click="add-role" phx-value-selected-role="<%= @selected_role %>">Add Role</button>
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
              <div id="snackbar" class="success-message"><%= @success_message %></div>
            <% end %>
          </div>

          <div class="associated-organizations-table">
            <h3>Roles Associated With This User</h3>
            <%= live_component(@socket, AndiWeb.EditUserLiveView.EditUserLiveViewRoleTable, user_roles: @user_roles, id: :edit_user_roles, self: @self) %>
          </div>

          <div class="associated-organizations-table">
            <h3>Organizations Associated With This User</h3>
            <%= live_component(@socket, AndiWeb.EditUserLiveView.EditUserLiveViewTable, organizations: @organizations, id: :edit_user_organizations) %>
          </div>
      </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "user" => user, "user_id" => user_id}, socket) do
    changeset = User.changeset(user, %{}) |> Map.put(:errors, [])
    signed_in_user = User.get_by_id(user_id)

    with {:ok, roles} <- Auth0Management.get_roles(),
         {:ok, user_roles} <- Auth0Management.get_user_roles(user.subject_id) do
      {:ok,
       assign(socket,
         is_curator: is_curator,
         changeset: changeset,
         roles: parse_roles(roles),
         user_roles: user_roles,
         organizations: user.organizations,
         user: user,
         success: false,
         success_message: "",
         click_id: nil,
         selected_role: "",
         self: is_self(signed_in_user, user)
       )}
    else
      {:error, error} ->
        Logger.error("unable to fetch role information from auth0: #{error}")

        {:ok,
         assign(socket,
           is_curator: is_curator,
           changeset: changeset,
           roles: [],
           user_roles: [],
           page_error: true,
           organizations: [],
           user: user,
           success: false,
           success_message: "",
           click_id: nil,
           selected_role: "",
           self: is_self(signed_in_user, user)
         )}
    end
  end

  def handle_event("validate", %{"_target" => ["form_data", "role"], "form_data" => %{"role" => role}}, socket) do
    {:noreply, assign(socket, selected_role: role)}
  end

  def handle_event("validate", _, socket) do
    {:noreply, socket}
  end

  def handle_event("add-role", %{"selected-role" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("add-role", %{"selected-role" => selected_role}, socket) do
    subject_id = socket.assigns.user.subject_id
    role_id = selected_role

    with {:ok, _} <- Auth0Management.assign_user_role(subject_id, role_id),
         {:ok, user_roles} <- Auth0Management.get_user_roles(subject_id) do
      {:noreply,
       assign(socket,
         user_roles: user_roles
       )}
    else
      {:error, error} ->
        Logger.error("unable to add role to user: #{error}")
        {:noreply, socket}
    end
  end

  def handle_event("associate", %{"organiation" => %{"org_id" => ""}}, socket) do
    {:noreply, socket}
  end

  def handle_event("associate", %{"organiation" => %{"org_id" => org_id}}, socket) do
    user = socket.assigns.user
    send_event(org_id, user)

    {:noreply,
     assign(socket,
       success: true,
       success_message: "Organization successfully associated. Please refresh to see the updated organizations.",
       click_id: UUID.uuid4()
     )}
  end

  def handle_event("associate", _, socket) do
    {:noreply, socket}
  end

  def handle_info({:disassociate_org, org_id}, socket) do
    user = socket.assigns.user

    {:ok, user_org_disassociation} = SmartCity.UserOrganizationDisassociate.new(%{subject_id: user.subject_id, org_id: org_id})
    Brook.Event.send(:andi, user_organization_disassociate(), :andi, user_org_disassociation)

    {:noreply,
     assign(socket,
       success: true,
       success_message: "Organization successfully disassociated. Please refresh to see the updated organizations.",
       click_id: UUID.uuid4()
     )}
  end

  def handle_info({:remove_role, role_id}, socket) do
    subject_id = socket.assigns.user.subject_id

    with {:ok, _} <- Auth0Management.delete_user_role(subject_id, role_id),
         {:ok, user_roles} <- Auth0Management.get_user_roles(subject_id) do
      {:noreply,
       assign(socket,
         user_roles: user_roles
       )}
    else
      {:error, error} ->
        Logger.error("unable to remove role from user: #{error}")
        {:noreply, socket}
    end
  end

  defp send_event(org_id, user) do
    {:ok, event_data} = UserOrganizationAssociate.new(%{subject_id: user.subject_id, org_id: org_id, email: user.email})
    Brook.Event.send(:andi, user_organization_associate(), :andi, event_data)
  end

  defp parse_roles(roles) when length(roles) == 0, do: []

  defp parse_roles(roles) do
    roles = roles |> Enum.map(fn %{"id" => id, "description" => description} -> {description, id} end)
    roles
  end

  defp is_self(signed_in_user, edit_user) do
    signed_in_user.subject_id == edit_user.subject_id
  end
end
