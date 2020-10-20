defmodule AndiWeb.HeaderLiveView do
  @moduledoc """
  LiveView for the header bar
  """
  use Phoenix.LiveView
  require Logger

  def mount(_, %{"roles" => roles}, socket) do
    {:ok,
     assign(socket,
       is_curator?: Enum.member?(roles, "Curator")
     )}
  end

  def render(assigns) do
    ~L"""
    <header class="root__header page-header">
      <span class="page-header__primary" phx-click="show-datasets">
        <span class="datasets-link__icon material-icons">home</span>
        <span class="datasets-link__text">Dataset Ingestion Interface</span>
      </span>
      <span class="page-header__secondary">
        <%= if @is_curator? do %>
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

  def handle_event("show-organizations", _, socket) do
    {:noreply, redirect(socket, to: "/organizations")}
  end

  def handle_event("show-datasets", _, socket) do
    {:noreply, redirect(socket, to: "/datasets")}
  end

  def handle_event("log-out", _, socket) do
    {:noreply, redirect(socket, to: "/auth/auth0/logout")}
  end
end
