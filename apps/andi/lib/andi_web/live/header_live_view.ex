defmodule AndiWeb.HeaderLiveView do
  @moduledoc """
  LiveView for the header bar
  """
  use Phoenix.LiveComponent

  def render(assigns) do
    ~L"""
    <header class="root__header page-header">
      <span class="page-header__primary datasets-link" phx-click="show-datasets">
        <span class="datasets-link__icon material-icons">home</span>
        <span class="datasets-link__text">Dataset Ingestion Interface</span>
      </span>
      <span class="page-header__secondary">
        <%= if @is_curator do %>
          <span class="organization-link" phx-click="show-organizations">
            <span class="organization-link__icon material-icons">settings</span>
            <span class="organization-link__text">ORGANIZATIONS</span>
          </span>
        <% end %>
        <span class="log-out-link" phx-click="log-out">
          <span class="log-out-link__icon material-icons">person</span>
          <span class="log-out-link__text">LOG OUT</span>
        </span>
      </span>
    </header>
    """
  end

  defmacro __using__(opts \\ []) do
    prompt_for_changes? = Keyword.get(opts, :prompt_for_changes?, false)

    quote do
      import AndiWeb.HeaderLiveView

      def render_header(socket, is_curator) do
        live_component(socket, AndiWeb.HeaderLiveView, is_curator: is_curator)
      end

      def handle_event("show-datasets", _, socket) do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_datasets_path(), unquote(prompt_for_changes?))
      end

      def handle_event("show-organizations", _, socket) do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_organizations_path(), unquote(prompt_for_changes?))
      end

      def handle_event("log-out", _, socket) do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_log_out_path(), unquote(prompt_for_changes?))
      end
    end
  end

  defmacro header_datasets_path() do
    "/datasets"
  end

  defmacro header_organizations_path() do
    "/organizations"
  end

  defmacro header_log_out_path() do
    "/auth/auth0/logout"
  end

  def __redirect__(%{assigns: %{unsaved_changes: true}} = socket, location, true = _prompt_for_changes?) do
    {:noreply, assign(socket, unsaved_changes_link: location, unsaved_changes_modal_visibility: "visible")}
  end

  def __redirect__(socket, location, _) do
    {:noreply, redirect(socket, to: location)}
  end
end
