defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  import Phoenix.HTML.Form
  import Ecto.Query, only: [from: 2]
  import SmartCity.Event

  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.Datasets.Dataset
  alias Andi.Schemas.User

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-page" id="access-groups-edit-page">
      <div class="edit-access-group-title">
        <h2 class="component-title-text access-groups-component-title-text">Edit Access Group </h2>
      </div>

      <hr class="search-modal-divider">

      <%= form = form_for @changeset, "#", [as: :form_data, phx_change: :form_change] %>
      <%= hidden_input(form, :id) %>
      <%= hidden_input(form, :description) %>

        <div class="access-group-form__name">
          <%= label(form, :name, class: "label label--required") do "Access Group Name" end %>
          <%= text_input(form, :name, class: "input") %>
        </div>

        <%= live_component(@socket, AndiWeb.AccessGroupLiveView.DatasetTable, selected_datasets: @selected_datasets) %>

        <div>
          <button class="btn btn--manage-datasets-search" phx-click="manage-datasets" type="button">Manage Datasets</button>
        </div>

        <%= live_component(@socket, AndiWeb.AccessGroupLiveView.UserTable, selected_users: @selected_users) %>

        <div>
          <button class="btn btn--manage-users-search" phx-click="manage-users" type="button">Manage Users</button>
        </div>
      </form>

      <%= live_component(@socket, AndiWeb.Search.ManageDatasetsModal, visibility: @manage_datasets_modal_visibility, search_results: @dataset_search_results, search_text: @dataset_search_text, selected_datasets: @selected_datasets) %>

      <%= live_component(@socket, AndiWeb.Search.ManageUsersModal, visibility: @manage_users_modal_visibility, search_results: @user_search_results, search_text: @user_search_text, selected_users: @selected_users) %>

      <div class="edit-page__btn-group" id="access-groups-edit-button-group">
      <div class="btn-group__standard">
            <button type="button" class="btn btn--large cancel-edit" phx-click="cancel-edit">Cancel</button>
            <button type="submit" id="save-button" name="save-button" phx-click="access-group-form_save" class="btn btn--action btn--large save-edit">Save</button>
        </div>

        <hr>

        <button id="access-group-delete-button" class="btn btn--delete" phx-click="prompt-access-group-delete" type="button">
          <span class="delete-icon material-icons">delete_outline</span>
          DELETE
        </button>
      </div>

      <%= live_component(@socket, AndiWeb.ConfirmDeleteModal, type: "Access Group", visibility: @delete_access_group_modal_visibility, id: @access_group.id) %>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "access_group" => access_group, "user_id" => user_id} = _session, socket) do
    default_changeset = AccessGroup.changeset(access_group, %{}) |> Map.put(:errors, [])

    access_group_with_datasets_and_users =
      Andi.Repo.get(Andi.InputSchemas.AccessGroup, access_group.id)
      |> Andi.Repo.preload([:datasets, :users])

    starting_dataset_ids = Enum.map(access_group_with_datasets_and_users.datasets, fn dataset -> dataset.id end)
    starting_user_ids = Enum.map(access_group_with_datasets_and_users.users, fn user -> user.subject_id end)

    {:ok,
     assign(socket,
       is_curator: is_curator,
       user_id: user_id,
       access_group: access_group_with_datasets_and_users,
       changeset: default_changeset,
       delete_access_group_modal_visibility: "hidden",
       manage_datasets_modal_visibility: "hidden",
       manage_users_modal_visibility: "hidden",
       dataset_search_results: [],
       user_search_results: [],
       dataset_search_text: "",
       user_search_text: "",
       selected_datasets: starting_dataset_ids,
       selected_users: starting_user_ids
     )}
  end

  def handle_event("cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: header_access_groups_path())}
  end

  def handle_event("save-dataset-search", _, socket) do
    {:noreply,
     assign(socket,
       manage_datasets_modal_visibility: "hidden",
       dataset_search_results: socket.assigns.dataset_search_results,
       selected_datasets: socket.assigns.selected_datasets
     )}
  end

  def handle_event("save-user-search", _, socket) do
    {:noreply,
     assign(socket,
       manage_users_modal_visibility: "hidden"
     )}
  end

  def handle_event("prompt-access-group-delete", _, socket) do
    {:noreply, assign(socket, delete_access_group_modal_visibility: "visible")}
  end

  def handle_event("delete-canceled", _, socket) do
    {:noreply, assign(socket, delete_access_group_modal_visibility: "hidden")}
  end

  def handle_event("delete-confirmed", _, socket) do
    access_group_id = socket.assigns.access_group.id
    user_id = socket.assigns.user_id

    access_group =
      Andi.Repo.get(Andi.InputSchemas.AccessGroup, access_group_id)
      |> Andi.Repo.preload([:datasets, :users])

    datasets = Enum.map(access_group.datasets, fn dataset -> dataset.id end)
    users = Enum.map(access_group.users, fn user -> user.subject_id end)

    send_dataset_disassociate_events(datasets, access_group_id, user_id)
    send_user_disassociate_events(users, access_group_id, user_id)
    AccessGroups.delete(access_group_id)
    Andi.Schemas.AuditEvents.log_audit_event(user_id, "access_group:delete", %{access_group_id: access_group_id})

    {:noreply, redirect(socket, to: header_access_groups_path())}
  end

  def handle_event("access-group-form_save", _, socket) do
    case socket.assigns.changeset |> Ecto.Changeset.apply_changes() |> AccessGroups.update() do
      {:ok, _} ->
        update_dataset_associations(socket)
        update_user_associations(socket)
        update_access_group_logs(socket.assigns.user_id, socket.assigns.changeset.changes)
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

  def handle_event("manage-datasets", _, socket) do
    {:noreply, assign(socket, manage_datasets_modal_visibility: "visible")}
  end

  def handle_event("manage-users", _, socket) do
    {:noreply, assign(socket, manage_users_modal_visibility: "visible")}
  end

  def handle_event("dataset-search", %{"search-value" => search_value}, socket) do
    search_results = query_on_dataset_search_change(search_value, socket)

    {:noreply,
     assign(socket,
       manage_datasets_modal_visibility: "visible",
       dataset_search_results: search_results,
       selected_datasets: socket.assigns.selected_datasets
     )}
  end

  def handle_event("user-search", %{"search-value" => search_value}, socket) do
    search_results = query_on_user_search_change(search_value, socket)

    {:noreply,
     assign(socket,
       manage_users_modal_visibility: "visible",
       user_search_results: search_results,
       selected_users: socket.assigns.selected_users
     )}
  end

  def handle_event("select-dataset-search", %{"id" => id}, socket) do
    update_dataset_selection(id, socket)
  end

  def handle_event("remove-selected-dataset", %{"id" => id}, socket) do
    update_dataset_selection(id, socket)
  end

  def handle_event("select-user-search", %{"id" => id}, socket) do
    update_user_selection(id, socket)
  end

  def handle_event("remove-selected-user", %{"id" => id}, socket) do
    update_user_selection(id, socket)
  end

  defp update_user_selection(id, socket) do
    case id in socket.assigns.selected_users do
      true ->
        selected_users = List.delete(socket.assigns.selected_users, id)
        {:noreply, assign(socket, add_user_modal_visibility: "visible", selected_users: selected_users)}

      _ ->
        selected_users = [id | socket.assigns.selected_users]
        {:noreply, assign(socket, add_user_modal_visibility: "visible", selected_users: selected_users)}
    end
  end

  defp update_dataset_selection(id, socket) do
    cond do
      id in socket.assigns.selected_datasets -> remove_from_selected_datasets(id, socket)
      true -> add_to_selected_datasets(id, socket)
    end
  end

  defp remove_from_selected_datasets(id, socket) do
    selected_datasets = List.delete(socket.assigns.selected_datasets, id)
    {:noreply, assign(socket, selected_datasets: selected_datasets)}
  end

  defp add_to_selected_datasets(id, socket) do
    selected_datasets = [id | socket.assigns.selected_datasets]
    {:noreply, assign(socket, selected_datasets: selected_datasets)}
  end

  defp query_on_dataset_search_change(search_value, %{assigns: %{dataset_search_text: search_value, dataset_search_results: search_results}}) do
    search_results
  end

  defp query_on_dataset_search_change(search_value, _) do
    refresh_dataset_search_results(search_value)
  end

  defp refresh_dataset_search_results(search_value) do
    like_search_string = "%#{search_value}%"

    query =
      from(dataset in Dataset,
        join: technical in assoc(dataset, :technical),
        join: business in assoc(dataset, :business),
        preload: [business: business, technical: technical],
        where: not is_nil(technical.id),
        where: not is_nil(business.id),
        where: ilike(business.dataTitle, type(^like_search_string, :string)),
        or_where: ilike(business.orgTitle, type(^like_search_string, :string)),
        or_where: ^search_value in business.keywords,
        select: dataset
      )

    query
    |> Andi.Repo.all()
  end

  defp query_on_user_search_change(search_value, %{assigns: %{user_search_text: search_value, user_search_results: search_results}}) do
    search_results
  end

  defp query_on_user_search_change(search_value, _) do
    refresh_user_search_results(search_value)
  end

  defp refresh_user_search_results(search_value) do
    find_all_matching_users(search_value)
    |> Enum.map(fn user -> user.subject_id end)
    |> find_all_users_with_all_organizations()
  end

  defp find_all_matching_users(search_value) do
    like_search_string = "%#{search_value}%"

    from(user in User,
      left_join: organizations in assoc(user, :organizations),
      preload: [organizations: organizations],
      where: ilike(user.email, type(^like_search_string, :string)),
      or_where: ilike(user.name, type(^like_search_string, :string)),
      or_where: ilike(organizations.orgTitle, type(^like_search_string, :string)),
      select: user
    )
    |> Andi.Repo.all()
  end

  defp find_all_users_with_all_organizations(subject_ids) do
    from(user in User,
      left_join: organizations in assoc(user, :organizations),
      preload: [organizations: organizations],
      where: user.subject_id in ^subject_ids,
      select: user
    )
    |> Andi.Repo.all()
  end

  def update_dataset_associations(socket) do
    access_group_id = socket.assigns.access_group.id
    user_id = socket.assigns.user_id

    original_ids = Enum.map(socket.assigns.access_group.datasets, fn dataset -> dataset.id end)
    datasets_to_disassociate = Enum.filter(original_ids, fn original -> original not in socket.assigns.selected_datasets end)
    datasets_to_associate = Enum.filter(socket.assigns.selected_datasets, fn selected -> selected not in original_ids end)

    send_dataset_associate_event(datasets_to_associate, access_group_id, user_id)
    send_dataset_disassociate_events(datasets_to_disassociate, access_group_id, user_id)
  end

  def update_user_associations(socket) do
    access_group_id = socket.assigns.access_group.id
    user_id = socket.assigns.user_id

    original_user_ids = Enum.map(socket.assigns.access_group.users, fn user -> user.subject_id end)
    users_to_disassociate = Enum.filter(original_user_ids, fn original -> original not in socket.assigns.selected_users end)
    users_to_associate = Enum.filter(socket.assigns.selected_users, fn selected -> selected not in original_user_ids end)

    send_user_associate_events(users_to_associate, access_group_id, user_id)
    send_user_disassociate_events(users_to_disassociate, access_group_id, user_id)
  end

  defp send_dataset_associate_event(datasets, access_group_id, user_id) do
    Enum.map(datasets, fn dataset ->
      properties = %{dataset_id: dataset, access_group_id: access_group_id}
      {:ok, relation} = SmartCity.DatasetAccessGroupRelation.new(properties)
      Andi.Schemas.AuditEvents.log_audit_event(user_id, dataset_access_group_associate(), relation)
      Andi.InputSchemas.Datasets.Dataset.associate_with_access_group(access_group_id, dataset)
      Brook.Event.send(:andi, dataset_access_group_associate(), :andi, relation)
    end)
  end

  defp send_dataset_disassociate_events(datasets, access_group_id, user_id) do
    Enum.map(datasets, fn dataset ->
      properties = %{dataset_id: dataset, access_group_id: access_group_id}
      {:ok, relation} = SmartCity.DatasetAccessGroupRelation.new(properties)
      Andi.Schemas.AuditEvents.log_audit_event(user_id, dataset_access_group_disassociate(), relation)
      Andi.InputSchemas.Datasets.Dataset.disassociate_with_access_group(access_group_id, dataset)
      Brook.Event.send(:andi, dataset_access_group_disassociate(), :andi, relation)
    end)
  end

  defp send_user_associate_events(users, access_group_id, user_id) do
    Enum.map(users, fn user ->
      properties = %{subject_id: user, access_group_id: access_group_id}
      {:ok, relation} = SmartCity.UserAccessGroupRelation.new(properties)
      Andi.Schemas.AuditEvents.log_audit_event(user_id, user_access_group_associate(), relation)
      Andi.Schemas.User.associate_with_access_group(user, access_group_id)
      Brook.Event.send(:andi, user_access_group_associate(), :andi, relation)
    end)
  end

  defp send_user_disassociate_events(users, access_group_id, user_id) do
    Enum.map(users, fn user ->
      properties = %{subject_id: user, access_group_id: access_group_id}
      {:ok, relation} = SmartCity.UserAccessGroupRelation.new(properties)
      Andi.Schemas.AuditEvents.log_audit_event(user_id, user_access_group_disassociate(), relation)
      Andi.Schemas.User.disassociate_with_access_group(user, access_group_id)
      Brook.Event.send(:andi, user_access_group_disassociate(), :andi, relation)
    end)
  end

  defp update_access_group_logs(user_id, %{id: _, name: _} = changes) do
    Andi.Schemas.AuditEvents.log_audit_event(user_id, "access_group:update", changes)
  end

  defp update_access_group_logs(_user_id, _changes), do: :ok
end
