defmodule AndiWeb.EditOrganizationLiveView do
  use AndiWeb, :live_view

  import Andi
  import Phoenix.HTML.Form
  import SmartCity.Event, only: [organization_update: 0]
  require Logger

  alias Andi.InputSchemas.InputConverter
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Organization
  alias AndiWeb.ErrorHelpers
  alias AndiWeb.Views.DisplayNames
  alias AndiWeb.Helpers.FormTools

  def render(assigns) do
    ~L"""
    <div id="edit-organization-live-view" class="organization-edit-page edit-page">
      <div class="page-header">
        <a phx-click="show-datasets">Dataset Ingestion Interface</a>
        <div class="organization-link" phx-click="show-organizations">
          <div class="organization-link__icon"></div>
          <div class="organization-link__text">ORGANIZATIONS</div>
        </div>
      </div>

      <div class="edit-organization-title">
        <h2 class="component-title-text">Edit Organization </h2>
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
            <%= text_input(f, :orgTitle, class: "input", phx_blur: "validate_unique_org_name") %>
            <%= ErrorHelpers.error_tag(f, :orgTitle, bind_to_input: false) %>
          </div>

          <div class="organization-form__name">
            <%= label(f, :orgName, DisplayNames.get(:orgName), class: "label label--required") %>
            <%= text_input(f, :orgName, [class: "input input--text", readonly: true]) %>
            <%= ErrorHelpers.error_tag(f, :orgName, bind_to_input: false) %>
          </div>

          <div class="organization-form__description">
            <%= label(f, :description, DisplayNames.get(:description), class: "label label--required") %>
            <%= textarea(f, :description, class: "input textarea") %>
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

        <div class="edit-button-group">
          <div class="edit-button-group__cancel-btn">
            <button type="button" class="btn btn--large" phx-click="cancel-edit">Cancel</button>
          </div>

          <div class="edit-button-group__save-btn">
            <button id="save-button" name="save-button" class="btn btn--action btn--large" type="button" phx-click="save">Save</button>
          </div>
        </div>
      </form>

      <%= live_component(@socket, AndiWeb.EditLiveView.UnsavedChangesModal, id: "edit-org-unsaved-changes-modal", visibility: @unsaved_changes_modal_visibility) %>
    </div>
    """
  end

  def mount(_params, %{"organization" => org}, socket) do
    changeset = Organization.changeset(org, %{}) |> Map.put(:errors, [])

    org_exists =
      case Andi.Services.OrgStore.get(org.id) do
        {:ok, nil} -> false
        _ -> true
      end

    {:ok,
     assign(socket,
       org: org,
       org_exists: org_exists,
       changeset: changeset,
       has_validation_errors: false,
       unsaved_changes: false,
       unsaved_changes_modal_visibility: "hidden",
       unsaved_changes_link: nil
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

    {:noreply, assign(socket, changeset: new_changeset, unsaved_changes: true)}
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    new_changeset =
      form_data
      |> AtomicMap.convert(safe: false, underscore: false)
      |> Organization.changeset()

    {:noreply, assign(socket, changeset: new_changeset, unsaved_changes: true)}
  end

  def handle_event("validate_unique_org_name", _, socket) do
    new_changeset =
      socket.assigns.changeset
      |> Organization.validate_unique_org_name()
      |> Map.put(:action, :update)

    {:noreply, assign(socket, changeset: new_changeset)}
  end

  def handle_event(redirect_event, _, %{assigns: %{unsaved_changes: true}} = socket)
      when redirect_event in ["cancel-edit", "show-organizations"] do
    {:noreply, assign(socket, unsaved_changes_modal_visibility: "visible", unsaved_changes_link: "/organizations")}
  end

  def handle_event("cancel-edit", _, socket) do
    {:noreply, redirect(socket, to: "/organizations")}
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

      case Brook.Event.send(instance_name(), organization_update(), __MODULE__, smrt_org) do
        :ok ->
          {:noreply, assign(socket, org: Organizations.get(socket.assigns.org.id), org_exists: true)}

        error ->
          Logger.warn("Unable to create new SmartCity.Organization: #{inspect(error)}")
      end
    else
      {:noreply, assign(socket, has_validation_errors: true)}
    end
  end

  def handle_event("show-organizations", _, socket) do
    {:noreply, redirect(socket, to: "/organizations")}
  end

  def handle_event("show-datasets", _, %{assigns: %{unsaved_changes: true}} = socket) do
    {:noreply, assign(socket, unsaved_changes_modal_visibility: "visible", unsaved_changes_link: "/datasets")}
  end

  def handle_event("show-datasets", _, socket) do
    {:noreply, redirect(socket, to: "/organizations")}
  end
end
