defmodule AndiWeb.HeaderLiveView do
  @moduledoc """
  LiveView for the header bar
  """
  use Phoenix.LiveComponent

  defmacro header_datasets_path() do
    "/datasets"
  end

  defmacro header_ingestions_path() do
    "/ingestions"
  end

  defmacro header_organizations_path() do
    "/organizations"
  end

  defmacro header_access_groups_path() do
    "/access-groups"
  end

  defmacro header_users_path() do
    "/users"
  end

  defmacro header_log_out_path() do
    "/auth/auth0/logout"
  end

  def render(assigns) do
    ~L"""
    <header class="page-header">
      <span class="page-header__primary" phx-click="show-datasets">
        <img id="header-logo" src=<%= get_logo() %>></img>
        <span><%= get_header_text() %></span>
        <span id="log-out-link" class="log-out-link primary-color-text" phx-click="log-out" phx-keydown="log-out" tabindex="0">
          <span class="material-icons">person</span>
          <span class="log-out-link__text">Log Out</span>
        </span>
      </span>
      <span class="page-header__secondary">
        <%= if @is_curator do %>
          <span id="datasets-link" class='link <%= show_selected_if_active(header_datasets_path(), assigns.path) %>' phx-click="show-datasets" phx-keydown="show-datasets" tabindex="0">
            <span class="material-icons">storage</span>
            <span>Datasets</span>
          </span>
          <span id="ingestions-link" class="link <%= show_selected_if_active(header_ingestions_path(), assigns.path) %>" phx-click="show-ingestions" phx-keydown="show-ingestions" tabindex="0">
            <span class="material-icons">input</span>
            <span>Ingestions</span>
          </span>
          <span id="organizations-link" class="link <%= show_selected_if_active(header_organizations_path(), assigns.path) %>" phx-click="show-organizations" phx-keydown="show-organizations" tabindex="0">
            <span class="material-icons">settings</span>
            <span>Organizations</span>
          </span>
          <span id="access-groups-link" class="link <%= show_selected_if_active(header_access_groups_path(), assigns.path) %>" phx-click="show-access-groups" phx-keydown="show-access-groups" tabindex="0">
            <span class="material-icons">lock</span>
            <span>Access Groups</span>
          </span>
          <span id="users-link" class="link <%= show_selected_if_active(header_users_path(), assigns.path) %>" phx-click="show-users" phx-keydown="show-users" tabindex="0">
            <span class="material-icons">people</span>
            <span>Users</span>
          </span>
        <% end %>
      </span>
    </header>
    """
  end

  defmacro __using__(_opts \\ []) do
    quote do
      import AndiWeb.HeaderLiveView

      @click %{}
      @enter %{"key" => "Enter"}
      @space %{"key" => " "}

      def handle_event("show-datasets", key, socket) when key in [@click, @enter, @space] do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_datasets_path())
      end

      def handle_event("show-organizations", key, socket) when key in [@click, @enter, @space] do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_organizations_path())
      end

      def handle_event("show-users", key, socket) when key in [@click, @enter, @space] do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_users_path())
      end

      def handle_event("show-access-groups", key, socket) when key in [@click, @enter, @space] do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_access_groups_path())
      end

      def handle_event("show-ingestions", key, socket) when key in [@click, @enter, @space] do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_ingestions_path())
      end

      def handle_event("log-out", key, socket) when key in [@click, @enter, @space] do
        AndiWeb.HeaderLiveView.__redirect__(socket, header_log_out_path())
      end

      def handle_event(_, _, socket) do
        {:noreply, socket}
      end
    end
  end

  def show_selected_if_active(match_path, current_path) do
    if match_path == current_path do
      "active-tab primary-color-text"
    else
      ""
    end
  end

  def header_render(is_curator, path) do
    live_component(AndiWeb.HeaderLiveView, is_curator: is_curator, path: path)
  end

  def __redirect__(%{assigns: %{unsaved_changes: true}} = socket, location) do
    {:noreply, assign(socket, unsaved_changes_link: location, unsaved_changes_modal_visibility: "visible")}
  end

  def __redirect__(socket, location) do
    {:noreply, redirect(socket, to: location)}
  end

  defp get_logo(), do: Application.get_env(:andi, :logo_url)
  defp get_header_text(), do: Application.get_env(:andi, :header_text)
end
