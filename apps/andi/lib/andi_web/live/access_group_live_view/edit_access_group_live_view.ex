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

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="edit-page" id="access-groups-edit-page">
      <div class="edit-access-group-title">
        <h2 class="component-title-text access-groups-component-title-text">Edit Access Group </h2>
      </div>

      <hr class="datasets-modal-divider">

      <%= form = form_for @changeset, "#", [as: :form_data, phx_change: :form_change] %>
      <%= hidden_input(form, :id) %>
      <%= hidden_input(form, :description) %>

        <div class="access-group-form__name">
          <%= label(form, :name, class: "label label--required") do "Access Group Name" end %>
          <%= text_input(form, :name, class: "input") %>
        </div>

        <%= live_component(@socket, AndiWeb.AccessGroupLiveView.DatasetTable, associated_datasets: @associated_datasets, selected_datasets: @selected_datasets, removed_datasets: @removed_datasets) %>

        <div class="access-group-form__datasets">
          <button class="btn btn--add-dataset-search" phx-click="add-dataset" type="button">+ Add Dataset</button>
        </div>
      </form>

      <%= live_component(@socket, AndiWeb.Search.AddDatasetModal, visibility: @add_dataset_modal_visibility, datasets: @datasets, search_text: @search_text, selected_datasets: @selected_datasets) %>

      <div class="edit-button-group" id="access-groups-edit-button-group">
        <div class="edit-button-group__cancel-btn">
          <button type="button" class="btn btn--large cancel-edit" phx-click="cancel-edit">Cancel</button>
        </div>
        <div class="edit-button-group__save-btn">
          <button type="submit" id="save-button" name="save-button" phx-click="access-group-form_save" class="btn btn--action btn--large save-edit">Save</button>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator, "access_group" => access_group, "user_id" => user_id} = _session, socket) do
    default_changeset = AccessGroup.changeset(access_group, %{}) |> Map.put(:errors, [])
    access_group_with_datasets = Andi.Repo.get(Andi.InputSchemas.AccessGroup, access_group.id) |> Andi.Repo.preload(:datasets)

    {:ok,
     assign(socket,
       is_curator: is_curator,
       user_id: user_id,
       access_group: access_group,
       changeset: default_changeset,
       add_dataset_modal_visibility: "hidden",
       datasets: [],
       search_text: "",
       selected_datasets: [],
       associated_datasets: access_group_with_datasets.datasets,
       removed_datasets: []
     )}
  end

  def handle_event("cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: header_access_groups_path())}
  end

  def handle_event("cancel-search", _, socket) do
    {:noreply, assign(socket, add_dataset_modal_visibility: "hidden")}
  end

  def handle_event("save-search", _, socket) do
    {:noreply,
     assign(socket,
       add_dataset_modal_visibility: "hidden",
       datasets: socket.assigns.datasets,
       selected_datasets: socket.assigns.selected_datasets
     )}
  end

  def handle_event("access-group-form_save", _, socket) do
    access_group_id = socket.assigns.access_group.id
    user_id = socket.assigns.user_id
    send_relation_event(dataset_access_group_associate(), socket.assigns.selected_datasets, access_group_id, user_id)
    send_relation_event(dataset_access_group_disassociate(), socket.assigns.removed_datasets, access_group_id, user_id)

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

  def handle_event("add-dataset", _, socket) do
    {:noreply, assign(socket, add_dataset_modal_visibility: "visible")}
  end

  def handle_event("search", %{"search-value" => search_value}, socket) do
    datasets = query_on_search_change(search_value, socket)

    {:noreply,
     assign(socket, add_dataset_modal_visibility: "visible", datasets: datasets, selected_datasets: socket.assigns.selected_datasets)}
  end

  def handle_event("select-search", %{"id" => id}, socket) do
    update_selection(id, socket)
  end

  def handle_event("remove-selected-dataset", %{"id" => id}, socket) do
    update_selection(id, socket)
  end

  def handle_event("remove-dataset", %{"id" => id}, socket) do
    cond do
      id in associated_datasets_ids(socket) -> remove_from_associated_datasets(id, socket)
    end
  end

  defp update_selection(id, socket) do
    cond do
      id in socket.assigns.selected_datasets -> remove_from_selected_datasets(id, socket)
      true -> add_to_selected_datasets(id, socket)
    end
  end

  defp associated_datasets_ids(socket) do
    Enum.map(socket.assigns.associated_datasets, fn dataset -> dataset.id end)
  end

  defp remove_from_selected_datasets(id, socket) do
    selected_datasets = List.delete(socket.assigns.selected_datasets, id)
    {:noreply, assign(socket, selected_datasets: selected_datasets)}
  end

  defp add_to_selected_datasets(id, socket) do
    selected_datasets = [id | socket.assigns.selected_datasets]
    {:noreply, assign(socket, selected_datasets: selected_datasets)}
  end

  defp remove_from_associated_datasets(id, socket) do
    removed_datasets = [id | socket.assigns.removed_datasets]
    {:noreply, assign(socket, removed_datasets: removed_datasets)}
  end

  defp query_on_search_change(search_value, %{assigns: %{search_text: search_value, datasets: datasets}}) do
    datasets
  end

  defp query_on_search_change(search_value, _) do
    refresh_datasets(search_value)
  end

  defp refresh_datasets(search_value) do
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

  defp send_relation_event(event_type, datasets, access_group_id, user_id) do
    Enum.map(datasets, fn dataset ->
      properties = %{dataset_id: dataset, access_group_id: access_group_id}
      {:ok, relation} = SmartCity.DatasetAccessGroupRelation.new(properties)
      Andi.Schemas.AuditEvents.log_audit_event(user_id, event_type, relation)
      Brook.Event.send(:andi, event_type, :andi, relation)
    end)
  end
end
