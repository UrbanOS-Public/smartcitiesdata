defmodule DiscoveryApiWeb.VisualizationController do
  require Logger
  use DiscoveryApiWeb, :controller

  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApiWeb.Utilities.AuthUtils
  alias DiscoveryApiWeb.Utilities.EctoAccessUtils

  plug(:accepts, DiscoveryApiWeb.VisualizationView.accepted_formats())

  def show(conn, %{"id" => id}) do
    with {:ok, %{query: query} = visualization} <- Visualizations.get_visualization_by_id(id),
         user <- Map.get(conn.assigns, :current_user, nil),
         true <- owns_visualization(visualization, user) || AuthUtils.authorized_to_query?(query, user, EctoAccessUtils) do
      render(conn, :visualization, %{visualization: visualization})
    else
      {:error, _} -> render_error(conn, 404, "Not Found")
      false -> render_error(conn, 404, "Not Found")
    end
  end

  def create(conn, %{"query" => query, "title" => title, "chart" => chart}) do
    with {:ok, user} <- Users.get_user_with_visualizations(conn.assigns.current_user, :subject_id),
         {:ok, json_chart} <- Jason.encode(chart),
         true <- under_visualizations_limit?(user),
         {:ok, visualization} <- Visualizations.create_visualization(%{query: query, title: title, chart: json_chart, owner: user}) do
      conn
      |> put_status(:created)
      |> render(:visualization, %{visualization: visualization})
    else
      _ -> render_error(conn, 400, "Bad Request")
    end
  end

  def update(conn, %{"id" => public_id, "chart" => chart} = attribute_changes) do
    with {:ok, user} <- Users.get_user(conn.assigns.current_user, :subject_id),
         {:ok, json_chart} <- Jason.encode(chart),
         changes_with_encoded_chart <- Map.put(attribute_changes, "chart", json_chart),
         {:ok, visualization} <- Visualizations.update_visualization_by_id(public_id, changes_with_encoded_chart, user) do
      render(conn, :visualization, %{visualization: visualization})
    else
      _ -> render_error(conn, 400, "Bad Request")
    end
  end

  defp owns_visualization(_visualization, nil), do: false

  defp owns_visualization(visualization, subject_id) do
    case Users.get_user(subject_id, :subject_id) do
      {:ok, user} -> user.id == visualization.owner_id
      _ -> false
    end
  end

  defp under_visualizations_limit?(%{visualizations: visualizations}) do
    Enum.count(visualizations) <= Application.get_env(:discovery_api, :user_visualization_limit)
  end
end
