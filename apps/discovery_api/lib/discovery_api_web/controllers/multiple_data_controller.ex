defmodule DiscoveryApiWeb.MultipleDataController do
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApiWeb.MultipleDataView
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApiWeb.Utilities.DescribeUtils
  import DiscoveryApiWeb.Utilities.StreamUtils

  plug(:accepts, MultipleDataView.accepted_formats())

  def query(conn, _params) do
    with {:ok, statement, conn} <- read_body(conn),
         {:ok, session} <- authorized_session(conn, statement) do
      format = get_format(conn)

      data_stream =
        Prestige.stream!(session, statement)
        |> Stream.flat_map(&Prestige.Result.as_maps/1)

      rendered_data_stream = MultipleDataView.render_as_stream(:data, format, %{stream: data_stream})

      resp_as_stream(conn, rendered_data_stream, format)
    else
      _ ->
        render_error(conn, 400, "Bad Request")
    end
  rescue
    Prestige.BadRequestError -> render_error(conn, 400, "Bad Request")
    error in [Prestige.Error] -> render_error(conn, 400, error)
  end

  def describe(conn, _params) do

    with {:ok, statement, conn} <- read_body(conn),
         {:ok, session} <- authorized_session(conn, statement) do
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

  defp authorized_session(conn, statement) do
    current_user = conn.assigns.current_user
    with true <- QueryAccessUtils.authorized_to_query?(statement, current_user),
         session_opts = DiscoveryApi.prestige_opts(),
         session = Prestige.new_session(session_opts) do
      {:ok, session}
    else
      false -> {:error, "Session not authorized"}
    end
  end
end
