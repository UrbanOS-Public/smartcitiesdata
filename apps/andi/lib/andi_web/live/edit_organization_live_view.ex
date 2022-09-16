defmodule AndiWeb.EditOrganizationLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  import Phoenix.HTML.Form
  import SmartCity.Event, only: [organization_update: 0, dataset_delete: 0]
  require Logger

  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Organization
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.Helpers.FormTools
  alias Andi.Services.DatasetStore

  @instance_name Andi.instance_name()

  def render(assigns) do
    ~L"""
    <%= header_render(@is_curator, AndiWeb.HeaderLiveView.header_organizations_path()) %>
    <div id="edit-organization-live-view" class="organization-edit-page edit-page">
      <div class="edit-organization-title">
        <h1 class="component-title-text">Edit Organization </h1>
      </div>

      <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data] %>
      <% f = Map.put(f, :errors, @changeset.errors) %>
        <%= hidden_input(f, :id) %>
        <%= hidden_input(f, :orgName) %>
        <%= hidden_input(f, :orgTitle) %>
        <%= hidden_input(f, :description) %>

        <div class="organization-form-edit-section form-grid">
          <div class="organization-form__title">
            <%= label(f, :orgTitle, DisplayNames.get(:orgTitle), class: "label label--required") %>
            <%= text_input(f, :orgTitle, [class: "input", phx_blur: "validate_unique_org_name", required: true]) %>
            <%= ErrorHelpers.error_tag(f, :orgTitle, bind_to_input: false) %>
          </div>

          <div class="organization-form__name">
            <%= label(f, :orgName, DisplayNames.get(:orgName), class: "label label--required") %>
            <%= text_input(f, :orgName, [class: "input input--text", readonly: true, required: true]) %>
            <%= ErrorHelpers.error_tag(f, :orgName, bind_to_input: false) %>
          </div>

          <div class="organization-form__description">
            <%= label(f, :description, DisplayNames.get(:description), class: "label label--required") %>
            <%= textarea(f, :description, class: "input textarea", required: true) %>
            <%= ErrorHelpers.error_tag(f, :description, bind_to_input: false) %>
          </div>

          <div class="organization-form__homepage">
            <%= label(f, :homepage, "Homepage", class: "label") %>
            <%= text_input(f, :homepage, class: "input") %>
            <%= ErrorHelpers.error_tag(f, :homepage, bind_to_input: false) %>
          </div>

          <div class="organization-form__data-json-url">
            <%= label(f, :dataJsonUrl, DisplayNames.get(:dataJsonUrl), class: "label") %>
            <%= text_input(f, :dataJsonUrl, class: "input") %>
            <%= ErrorHelpers.error_tag(f, :dataJsonUrl, bind_to_input: false) %>
          </div>

          <div class="organization-form__logo-url">
            <%= label(f, :logoUrl, DisplayNames.get(:logoUrl), class: "label") %>
            <%= text_input(f, :logoUrl, class: "input") %>
            <%= ErrorHelpers.error_tag(f, :logoUrl, bind_to_input: false) %>
          </div>
        </div>

        <div class="btn-group__standard" >
          <button id="save-button" name="save-button" class="btn btn--primary btn--action btn--large" type="button" phx-click="save">Save Organization</button>
          <button type="button" class="btn btn--secondary btn--large" phx-click="cancel-edit">Discard Changes</button>
        </div>
      </form>

      <div class="harvested-datasets-table">
        <h3>Remote Datasets Attached To This Organization</h3>

        <%= live_component(@socket, AndiWeb.OrganizationLiveView.HarvestedDatsetsTable, datasets: @harvested_datasets, order: @order) %>
      </div>

      <%= live_component(@socket, AndiWeb.UnsavedChangesModal, id: "edit-org-unsaved-changes-modal", visibility: @unsaved_changes_modal_visibility) %>

      <%= live_component(@socket, AndiWeb.EditLiveView.PublishSuccessModal, visibility: @publish_success_modal_visibility) %>

      <div phx-hook="showSnackbar">
        <%= if @has_validation_errors do %>
          <div id="snackbar" class="error-message">There were errors with the organization you tried to submit</div>
        <% end %>

      </div>

    </div>
    """
  end

  def mount(_params, %{"organization" => org, "is_curator" => is_curator, "user_id" => user_id}, socket) do
    changeset = Organization.changeset(org, %{}) |> Map.put(:errors, [])

    org_exists =
      case Andi.Services.OrgStore.get(org.id) do
        {:ok, nil} -> false
        _ -> true
      end

    harvested_datasets =
      org.id
      |> Organizations.get_all_harvested_datasets()
      |> Enum.map(&to_view_model/1)
      |> sort_by_dir("data_title", "asc")

    {:ok,
     assign(socket,
       org: org,
       org_exists: org_exists,
       changeset: changeset,
       has_validation_errors: false,
       unsaved_changes: false,
       unsaved_changes_link: nil,
       unsaved_changes_modal_visibility: "hidden",
       publish_success_modal_visibility: "hidden",
       order: %{"data_title" => "asc"},
       params: %{},
       harvested_datasets: harvested_datasets,
       is_curator: is_curator,
       user_id: user_id
     )}
  end

  def handle_event(
        "validate",
        %{"form_data" => form_data, "_target" => ["form_data", "orgTitle" | _]},
        %{assigns: %{org_exists: false}} = socket
      ) do
    new_changeset =
      form_data
      |> FormTools.adjust_org_name_from_org_title()
      |> AtomicMap.convert(safe: false, underscore: false)
      |> Organization.changeset()

    {:noreply, assign(socket, changeset: new_changeset, unsaved_changes: true, has_validation_errors: false)}
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    new_changeset =
      form_data
      |> AtomicMap.convert(safe: false, underscore: false)
      |> Organization.changeset()

    {:noreply, assign(socket, changeset: new_changeset, unsaved_changes: true, has_validation_errors: false)}
  end

  def handle_event("validate_unique_org_name", _, socket) do
    new_changeset =
      socket.assigns.changeset
      |> Organization.validate_unique_org_name()
      |> Map.put(:action, :update)

    {:noreply, assign(socket, changeset: new_changeset)}
  end

  def handle_event("cancel-edit", _, %{assigns: %{unsaved_changes: true}} = socket) do
    {:noreply, assign(socket, unsaved_changes_modal_visibility: "visible", unsaved_changes_link: header_organizations_path())}
  end

  def handle_event("cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: header_organizations_path())}
  end

  def handle_event("force-cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: socket.assigns.unsaved_changes_link)}
  end

  def handle_event("unsaved-changes-canceled", _, socket) do
    {:noreply, assign(socket, unsaved_changes_modal_visibility: "hidden")}
  end

  def handle_event("save", _, socket) do
    if socket.assigns.changeset.valid? do
      {:ok, smrt_org} =
        socket.assigns.changeset
        |> Ecto.Changeset.apply_changes()
        |> InputConverter.andi_org_to_smrt_org()

      Andi.Schemas.AuditEvents.log_audit_event(socket.assigns.user_id, organization_update(), smrt_org)

      case Brook.Event.send(@instance_name, organization_update(), __MODULE__, smrt_org) do
        :ok ->
          {:noreply,
           assign(socket,
             org: Organizations.get(socket.assigns.org.id),
             org_exists: true,
             unsaved_changes: false,
             publish_success_modal_visibility: "visible"
           )}

        error ->
          Logger.warn("Unable to create new SmartCity.Organization: #{inspect(error)}")
      end
    else
      {:noreply, assign(socket, has_validation_errors: true)}
    end
  end

  def handle_event("toggle_include", %{"id" => id}, socket) do
    case Organizations.get_harvested_dataset(id) do
      %{include: true} ->
        dataset_delete_event(id)
        Organizations.update_harvested_dataset_include(id, false)
        {:noreply, socket}

      %{include: false} ->
        Organizations.update_harvested_dataset_include(id, true)
        {:noreply, socket}
    end
  end

  def handle_event("reload-page", _, socket) do
    {:noreply, redirect(socket, to: "/organizations/#{socket.assigns.org.id}")}
  end

  def handle_event("order-by", %{"field" => field}, socket) do
    order_dir =
      case socket.assigns.order do
        %{^field => "asc"} -> "desc"
        _ -> "asc"
      end

    sorted_datasets = sort_by_dir(socket.assigns.harvested_datasets, field, order_dir)
    {:noreply, assign(socket, harvested_datasets: sorted_datasets, order: %{field => order_dir})}
  end

  defp sort_by_dir(models, order_by, order_dir) do
    case order_dir do
      "asc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end)
      "desc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end, &>=/2)
      _ -> models
    end
  end

  defp to_view_model(dataset) do
    %{
      "dataset_id" => dataset.datasetId,
      "data_title" => dataset.dataTitle,
      "source" => dataset.source,
      "modified_date" => to_string(dataset.modifiedDate),
      "include" => dataset.include
    }
  end

  defp dataset_delete_event(id) do
    case DatasetStore.get(id) do
      {:ok, dataset} ->
        Brook.Event.send(@instance_name, dataset_delete(), :andi, dataset)

      _ ->
        Logger.info("dataset not in system: #{id}")
    end
  end
end
