defmodule AndiWeb.UserLiveView do
  use AndiWeb, :live_view
  use AndiWeb.HeaderLiveView

  import Ecto.Query, only: [from: 2]

  alias AndiWeb.Router.Helpers, as: Routes
  alias AndiWeb.UserLiveView.Table
  alias Andi.Schemas.User

  access_levels(render: [:private])

  def render(assigns) do
    ~L"""
    <%= header_render(@socket, @is_curator) %>
    <div class="users-view">
      <div class="users-index">
        <div class="users-index__header">
          <h1 class="users-index__title">All Users</h1>
        </div>

        <div class="users-index__search">
          <form phx-change="search" phx-submit="search">
            <div class="users-index__search-input-container">
              <label for="users-index__search-input">
                <i class="material-icons users-index__search-icon">search</i>
              </label>
              <input
                name="search-value"
                phx-debounce="250"
                id="users-index__search-input"
                class="users-index__search-input"
                type="text"
                value="<%= @search_text %>"
                placeholder="Search Users"
              >
            </div>
          </form>
        </div>
        <%= live_component(@socket, Table, id: :users_table, users: @users, order: @order) %>
    </div>
    """
  end

  def mount(_params, %{"is_curator" => is_curator}, socket) do
    {:ok,
     assign(socket,
       users: nil,
       search_text: nil,
       order: {"email", "asc"},
       params: %{},
       is_curator: is_curator
     )}
  end

  def handle_params(params, _uri, socket) do
    order_by = Map.get(params, "order-by", "email")
    order_dir = Map.get(params, "order-dir", "asc")
    search_text = Map.get(params, "search", "")

    view_models =
      filter_on_search_change(search_text, socket)
      |> sort_by_dir(order_by, order_dir)

    {:noreply,
     assign(socket,
       search_text: search_text,
       users: view_models,
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

  defp filter_on_search_change(search_value, socket) do
    case search_value == socket.assigns.search_text do
      false -> refresh_users(search_value)
      _ -> socket.assigns.users
    end
  end

  defp refresh_users(search_value) do
    search_string = "%#{search_value}%"

    query =
      from(user in User,
        where: ilike(user.email, type(^search_string, :string)),
        select: user
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

  defp to_view_model(user) do
    %{
      "email" => user.email,
      "id" => user.id
    }
  end
end
