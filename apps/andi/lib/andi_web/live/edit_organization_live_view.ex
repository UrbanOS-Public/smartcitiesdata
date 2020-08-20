defmodule AndiWeb.EditOrganizationLiveView do
  use Phoenix.LiveView
  import Phoenix.HTML.Form

  alias Andi.InputSchemas.Organization
  alias AndiWeb.ErrorHelpers

  def render(assigns) do
    ~L"""
    <div id="edit-organization-live-view" class="organization-edit-page edit-page">
      <div class="page-header">
        <a href="/datasets">Dataset Ingestion Interface</a>
        <div class="organization-link" phx-click="show-organizations">
          <div class="organization-link__icon"></div>
          <div class="organization-link__text">ORGANIZATIONS</div>
        </div>
      </div>

      <div class="edit-organization-title">
        <h2 class="component-title-text">Edit Organization </h2>
      </div>

      <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data] %>
        <div class="organization-form-edit-section form-grid">
          <div class="organization-form__name">
            <%= label(f, :orgTitle, "Organization Name", class: "label label--required") %>
            <%= text_input(f, :orgTitle, class: "input") %>
            <%= ErrorHelpers.error_tag(f, :orgTitle, bind_to_input: false) %>
          </div>

          <div class="organization-form__description">
            <%= label(f, :description, "Description", class: "label label--required") %>
            <%= textarea(f, :description, class: "input textarea") %>
            <%= ErrorHelpers.error_tag(f, :description, bind_to_input: false) %>
          </div>

          <div class="organization-form__homepage">
            <%= label(f, :homepage, "Homepage", class: "label label--required") %>
            <%= text_input(f, :homepage, class: "input") %>
            <%= ErrorHelpers.error_tag(f, :homepage, bind_to_input: false) %>
          </div>

          <div class="organization-form__data-json-url">
            <%= label(f, :dataJSONUrl, "Data JSON URL", class: "label") %>
            <%= text_input(f, :dataJSONUrl, class: "input") %>
            <%= ErrorHelpers.error_tag(f, :dataJSONUrl, bind_to_input: false) %>
          </div>

          <div class="organization-form__logo-url">
            <%= label(f, :logoUrl, "Logo URL", class: "label") %>
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
    </div>
    """
  end

  def mount(params, %{"organization" => org} = session, socket) do
    changeset = Organization.changeset(org, %{})

    {:ok, assign(socket, org: org, changeset: changeset)}
  end

  def handle_event("validate", %{"form_data" => form_data}, socket) do
    new_changeset =
      form_data
      |> AtomicMap.convert(safe: false, underscore: false)
      |> Organization.changeset()
      |> IO.inspect

    {:noreply, assign(socket, changeset: new_changeset)}
  end
end
