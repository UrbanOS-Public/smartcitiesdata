defmodule AndiWeb.OrganizationLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView
  use AndiWeb.FooterLiveView

  import Ecto.Query, only: [from: 2]

  alias AndiWeb.Router.Helpers, as: Routes
  alias AndiWeb.OrganizationLiveView.Table
  alias Andi.InputSchemas.Organizations
  alias Andi.InputSchemas.Organization
  alias Andi.Scripts.ResendEvents

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <div class="content">
      <%= header_render(@is_curator, AndiWeb.HeaderLiveView.header_organizations_path()) %>
      <main aria-label="Add and manage organizations" class="organizations-view">
        <div class="organizations-index">
          <div class="organizations-index__header">
            <h1 class="organizations-index__title">All Organizations</h1>
            <div class="organizations-index__header-actions">
              <button type="button" class="btn btn--secondary btn--action" phx-click="resync-orgs" <%= if @resync_status == :running, do: "disabled" %>>
                <%= if @resync_status == :running, do: "Syncing...", else: "Resync Orgs to Redis" %>
              </button>
              <button type="button" class="btn btn--primary  btn--action" phx-click="add-organization">+ Add Organization</button>
            </div>
          </div>
          <%= if @resync_status == :done do %>
            <div class="resync-status resync-status--success">Orgs successfully resynced to Redis.</div>
          <% end %>
          <%= if @resync_status == :error do %>
            <div class="resync-status resync-status--error">Resync encountered errors — check server logs.</div>
          <% end %>
          <hr class="organizations-line">

          <div class="organizations-index__search">
            <form phx-change="search" phx-submit="search">
              <div class="organizations-index__search-input-container">
                <label for="organizations-index__search-input">
                  <i class="material-icons organizations-index__search-icon">search</i>
                </label>
                <input
                  name="search-value"
                  phx-debounce="250"
                  id="organizations-index__search-input"
                  class="organizations-index__search-input"
                  type="text"
                  value="<%= @search_text %>"
                  placeholder="Search Organizations"
                >
              </div>
            </form>
          </div>

          <%= live_component(@socket, Table, id: :organizations_table, organizations: @organizations, order: @order) %>
        </div>
      </main>
      <%= footer_render(@is_curator) %>
      </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator}, socket) do
    {:ok,
     assign(socket,
       organizations: nil,
       search_text: nil,
       order: {"org_title", "asc"},
       params: %{},
       is_curator: is_curator,
       resync_status: nil
     )}
  end

  def handle_params(params, _uri, socket) do
    order_by = Map.get(params, "order-by", "org_title")
    order_dir = Map.get(params, "order-dir", "asc")
    search_text = Map.get(params, "search", "")

    view_models =
      filter_on_search_change(search_text, socket)
      |> sort_by_dir(order_by, order_dir)

    {:noreply,
     assign(socket,
       search_text: search_text,
       organizations: view_models,
       order: %{order_by => order_dir},
       params: params
     )}
  end

  def handle_event("search", %{"search-value" => value}, socket) do
    search_params = Map.merge(socket.assigns.params, %{"search" => value})
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, search_params))}
  end

  def handle_event("order-by", %{"field" => field}, socket) do
    order_dir =
      case socket.assigns.order do
        %{^field => "asc"} -> "desc"
        _ -> "asc"
      end

    params = Map.merge(socket.assigns.params, %{"order-by" => field, "order-dir" => order_dir})
    {:noreply, push_patch(socket, to: Routes.live_path(socket, __MODULE__, params))}
  end

  def handle_event("add-organization", _, socket) do
    new_org = Organizations.create()

    {:noreply, push_redirect(socket, to: "/organizations/#{new_org.id}")}
  end

  def handle_event("resync-orgs", _, socket) do
    caller = self()

    Task.start(fn ->
      try do
        ResendEvents.resend_org_events()
        send(caller, {:resync_result, :done})
      rescue
        e ->
          require Logger
          Logger.error("resync-orgs failed: #{inspect(e)}")
          send(caller, {:resync_result, :error})
      end
    end)

    {:noreply, assign(socket, resync_status: :running)}
  end

  def handle_info({:resync_result, status}, socket) do
    {:noreply, assign(socket, resync_status: status)}
  end

  defp filter_on_search_change(search_value, socket) do
    case search_value == socket.assigns.search_text do
      false -> refresh_orgs(search_value)
      _ -> socket.assigns.organizations
    end
  end

  defp refresh_orgs(search_value) do
    search_string = "%#{search_value}%"

    query =
      from(org in Organization,
        where: ilike(org.orgTitle, type(^search_string, :string)),
        select: org
      )

    Andi.Repo.all(query)
    |> Enum.map(&to_view_model/1)
  end

  defp sort_by_dir(models, order_by, order_dir) do
    case order_dir do
      "asc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end)
      "desc" -> Enum.sort_by(models, fn model -> Map.get(model, order_by) end, &>=/2)
      _ -> models
    end
  end

  defp to_view_model(org) do
    %{
      "org_title" => org.orgTitle,
      "id" => org.id
    }
  end
end
