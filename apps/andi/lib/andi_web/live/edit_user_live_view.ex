defmodule AndiWeb.EditUserLiveView do
    use AndiWeb, :live_view
    use AndiWeb.HeaderLiveView

    import Phoenix.HTML.Form
    import SmartCity.Event, only: [organization_update: 0, dataset_delete: 0]

    alias Andi.Schemas.User
  
    def render(assigns) do
      ~L"""
      <%= header_render(@socket, @is_curator) %>
        <div id="edit-user-live-view" class="user-edit-page edit-page">
            <div class="edit-user-title">
                <h2 class="component-title-text">Edit User </h2>
            </div>

            <%= f = form_for @changeset, "#", [phx_change: :validate, as: :form_data] %>
                <div class="user-form-edit-section">
                    <div class="user-form__title">
                        <%= label(f, :email, class: "label label--required") %>
                        <%= text_input(f, :email, class: "input") %>
                    </div>
                <div>
            </form>
        </div>
      """
    end
  
    def mount(_params, %{"is_curator" => is_curator, "user" => user}, socket) do
        changeset = User.changeset(user, %{}) |> Map.put(:errors, [])

        {:ok, assign(socket, is_curator: is_curator, changeset: changeset)}
    end
  
  end
  