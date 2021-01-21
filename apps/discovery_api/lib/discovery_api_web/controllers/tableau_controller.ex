require Logger

defmodule DiscoveryApiWeb.TableauController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.Utilities.ModelAccessUtils
  alias DiscoveryApiWeb.SearchView
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Data.TableInfoCache
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApiWeb.Utilities.DescribeUtils
  alias DiscoveryApiWeb.MultipleDataView

  @matched_params [
    %{"query" => "", "limit" => "10", "offset" => "0", "apiAccessible" => "false"},
    %{"limit" => "10", "offset" => "0", "apiAccessible" => "false"}
  ]

  plug(:accepts, SearchView.accepted_formats())
  plug(DiscoveryApiWeb.Plugs.ResponseCache, %{for_params: @matched_params} when action in [:search])

  def fetch_table_info(conn, _params) do
    user_id = get_user_id(conn)

    filtered_tables =
      case TableInfoCache.get(user_id) do
        nil ->
          remove_unauthorized_models(conn, Model.get_all())
          |> get_filtered_table_info()
          |> TableInfoCache.put(user_id)

        filtered_tables ->
          filtered_tables
      end

    render(
      conn,
      :fetch_table_info,
      table_infos: filtered_tables
    )
  end

  def describe(conn, _params) do
    with {:ok, statement, conn} <- read_body(conn),
         {:ok, affected_models} <- QueryAccessUtils.get_affected_models(statement),
         {:ok, session} <- QueryAccessUtils.authorized_session(conn, affected_models) do
      format = get_format(conn)

      query_schema =
        session
        |> Prestige.prepare!("describable_statement", statement)
        |> Prestige.execute!("describe output describable_statement")
        |> Prestige.Result.as_maps()
        |> DescribeUtils.convert_description()

      response = MultipleDataView.render(:describe, format, %{rows: query_schema})
      resp(conn, 200, response)
    else
      _ ->
        render_error(conn, 400, "Bad Request")
    end
  rescue
    Prestige.BadRequestError -> render_error(conn, 400, "Bad Request")
    error in [Prestige.Error] -> render_error(conn, 400, error)
  end

  defp get_user_id(conn) do
    case conn.assigns.current_user do
      nil -> nil
      user -> Map.get(user, :subject_id)
    end
  end

  defp get_filtered_table_info(models) do
    models
    |> filter_by_file_types(["CSV", "GEOJSON"])
    |> filter_by_source_type(true)
    |> Enum.map(&Model.to_table_info/1)
  end

  defp filter_by_file_types(datasets, accepted_file_types) do
    Enum.filter(datasets, fn dataset ->
      matching_file_types =
        dataset.fileTypes
        |> Enum.filter(&Enum.member?(accepted_file_types, &1))

      Enum.count(matching_file_types) > 0
    end)
  end

  defp filter_by_source_type(datasets, false), do: datasets

  defp filter_by_source_type(datasets, true) do
    Enum.filter(datasets, fn dataset -> dataset.sourceType in ["ingest", "stream"] end)
  end

  defp remove_unauthorized_models(conn, filtered_tabl) do
    current_user = conn.assigns.current_user
    Enum.filter(filtered_tabl, &ModelAccessUtils.has_access?(&1, current_user))
  end
end
