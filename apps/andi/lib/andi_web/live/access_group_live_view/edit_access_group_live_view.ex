defmodule AndiWeb.AccessGroupLiveView.EditAccessGroupLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  require Logger

  import Phoenix.HTML.Form
  import Ecto.Query, only: [from: 2]

  alias Andi.InputSchemas.AccessGroup
  alias Andi.InputSchemas.AccessGroups
  alias Andi.InputSchemas.Datasets.Dataset

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

        <div class="access-group-form__datasets">
          <button class="btn btn--add-dataset-search" phx-click="add-dataset" type="button">+ Add Dataset</button>
        </div>
      </form>

      <%= live_component(@socket, AndiWeb.Search.AddDatasetModal, visibility: @add_dataset_modal_visibility, datasets: @datasets, search_text: @search_text, selected_datasets: @selected_datasets) %>

      <div class="edit-button-group">
        <div class="edit-button-group__cancel-btn">
          <button type="button" class="btn btn--large cancel-edit" phx-click="cancel-edit">Cancel</button>
        </div>
        <div class="edit-button-group__save-btn">
          <button type="submit" id="save-button" name="save-button" phx-click="form_save" class="btn btn--action btn--large save-edit">Save</button>
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
       changeset: default_changeset,
       add_dataset_modal_visibility: "hidden",
       datasets: [],
       search_text: "",
       selected_datasets: []
     )}
  end

  def handle_event("cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: header_access_groups_path())}
  end

  def handle_event("cancel-search", _, socket) do
    {:noreply, assign(socket, add_dataset_modal_visibility: "hidden")}
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

  def handle_event("add-dataset", _, socket) do
    {:noreply, assign(socket, add_dataset_modal_visibility: "visible")}
  end

  def handle_event("search", %{"search-value" => search_value}, socket) do
    datasets = query_on_search_change(search_value, socket)
    {:noreply, assign(socket, add_dataset_modal_visibility: "visible", datasets: datasets)}
  end

  def handle_event("select-search", %{"id" => id}, socket) do
    case id in socket.assigns.selected_datasets do
      true ->
        selected_datasets = List.delete(socket.assigns.selected_datasets, id)
        {:noreply, assign(socket, add_dataset_modal_visibility: "visible", selected_datasets: selected_datasets)}

      _ ->
        selected_datasets = [id | socket.assigns.selected_datasets]
        {:noreply, assign(socket, add_dataset_modal_visibility: "visible", selected_datasets: selected_datasets)}
    end
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
end
