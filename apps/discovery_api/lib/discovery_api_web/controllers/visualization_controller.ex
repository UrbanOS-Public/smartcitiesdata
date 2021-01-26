defmodule DiscoveryApiWeb.VisualizationController do
  require Logger
  use DiscoveryApiWeb, :controller
  use Properties, otp_app: :discovery_api

  alias DiscoveryApi.Schemas.Visualizations
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils

  @owner_allowed_actions [%{name: :update}, %{name: :create_copy}]

  plug(:accepts, DiscoveryApiWeb.VisualizationView.accepted_formats())

  getter(:user_visualization_limit, generic: true)

  def index(conn, _body) do
    with user <- Map.get(conn.assigns, :current_user),
         visualizations <- Visualizations.get_visualizations_by_owner_id(user.id) do
      render(conn, :visualizations, %{visualizations: visualizations, allowed_actions: @owner_allowed_actions})
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, %{query: query} = visualization} <- Visualizations.get_visualization_by_id(id),
         user = Map.get(conn.assigns, :current_user),
         {:ok, authorized_models} <- QueryAccessUtils.get_affected_models(query),
         true <-
           owns_visualization(visualization, user) || QueryAccessUtils.user_can_access_models?(authorized_models, user) do
      allowed_actions = get_allowed_actions(visualization, user)
      render(conn, :visualization, %{visualization: visualization, allowed_actions: allowed_actions})
    else
      {:error, _} -> render_error(conn, 404, "Not Found")
      false -> render_error(conn, 404, "Not Found")
    end
  end

  def create(conn, %{"query" => query, "title" => title, "chart" => chart}) do
    with user <- Map.get(conn.assigns, :current_user),
         visualizations <- Visualizations.get_visualizations_by_owner_id(user.id),
         true <- under_visualizations_limit?(visualizations),
         {:ok, json_chart} <- Jason.encode(chart),
         {:ok, visualization} <- Visualizations.create_visualization(%{query: query, title: title, chart: json_chart, owner: user}) do
      allowed_actions = get_allowed_actions(visualization, user)

      conn
      |> put_status(:created)
      |> render(:visualization, %{visualization: visualization, allowed_actions: allowed_actions})
    else
      _ -> render_error(conn, 400, "Bad Request")
    end
  end

  def update(conn, %{"id" => public_id, "chart" => chart} = attribute_changes) do
    parsed_attributes = parse_attributes(attribute_changes)

    with user <- Map.get(conn.assigns, :current_user),
         {:ok, json_chart} <- Jason.encode(chart),
         changes_with_encoded_chart <- Map.put(parsed_attributes, :chart, json_chart),
         {:ok, visualization} <- Visualizations.update_visualization_by_id(public_id, changes_with_encoded_chart, user) do
      allowed_actions = get_allowed_actions(visualization, user)
      render(conn, :visualization, %{visualization: visualization, allowed_actions: allowed_actions})
    else
      _ -> render_error(conn, 400, "Bad Request")
    end
  end

  def delete(conn, %{"id" => public_id}) do
    with user <- Map.get(conn.assigns, :current_user),
         {:ok, visualization} <- Visualizations.get_visualization_by_id(public_id),
         true <- owns_visualization(visualization, user),
         {:ok, _} <- Visualizations.delete_visualization(visualization) do
      send_resp(conn, 204, "")
    else
      _ -> render_error(conn, 400, "Bad Request")
    end
  end

  defp owns_visualization(_visualization, nil), do: false

  defp owns_visualization(visualization, user) do
    user.id == visualization.owner_id
  end

  defp under_visualizations_limit?(visualizations) do
    Enum.count(visualizations) <= user_visualization_limit()
  end

  defp get_allowed_actions(_visualization, nil), do: []

  defp get_allowed_actions(visualization, user) do
    case owns_visualization(visualization, user) do
      true -> @owner_allowed_actions
      false -> [%{name: :create_copy}]
    end
  end

  defp parse_attributes(attributes) do
    attributes
    |> Enum.filter(fn {k, _v} -> k in ["chart", "query", "title"] end)
    |> Map.new(fn {k, v} -> {String.to_existing_atom(k), v} end)
  end
end
