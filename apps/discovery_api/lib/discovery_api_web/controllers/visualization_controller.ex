defmodule DiscoveryApiWeb.VisualizationController do
  require Logger
  use DiscoveryApiWeb, :controller

  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations

  plug(:accepts, DiscoveryApiWeb.VisualizationView.accepted_formats())

  def show(conn, %{"id" => id}) do
    case Visualizations.get_visualization_by_id(id) do
      {:error, _} -> render_error(conn, 404, "Not Found")
      {:ok, visualization} -> render(conn, :visualization, %{visualization: visualization})
    end
  end

  def create(conn, %{"query" => query, "title" => title}) do
    with {:ok, user} <- Users.get_user(conn.assigns.current_user),
         {:ok, visualization} <- Visualizations.create_visualization(%{query: query, title: title, owner: user}) do
      conn
      |> put_status(:created)
      |> render(:visualization, %{visualization: visualization})
    else
      _ -> render_error(conn, 400, "Bad Request")
    end
  end

  def update(conn, %{"id" => public_id} = attribute_changes) do
    with {:ok, user} <- Users.get_user(conn.assigns.current_user),
         {:ok, visualization} <- Visualizations.update_visualization_by_id(public_id, attribute_changes, user) do
      render(conn, :visualization, %{visualization: visualization})
    else
      _ ->
        render_error(conn, 400, "Bad Request")
    end
  end
end
