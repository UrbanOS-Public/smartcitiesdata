defmodule DiscoveryApiWeb.MultipleDataController do
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApiWeb.MultipleDataView
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApi.Services.{PrestoService, QueryCache}
  import DiscoveryApiWeb.Utilities.StreamUtils

  import SmartCity.Event,
    only: [dataset_query: 0]

  @prestige_impl Application.compile_env(:discovery_api, :prestige, Prestige)
  @prestige_result_impl Application.compile_env(:discovery_api, :prestige_result, Prestige.Result)

  plug(:accepts, MultipleDataView.accepted_formats())

  def query(conn, params) do
    query_start_ms = System.monotonic_time(:millisecond)
    conn = assign(conn, :query_start_ms, query_start_ms)
    do_query(conn, params, query_start_ms)
  end

  # query_start_ms is threaded through as a function argument (bound at entry, not
  # inside this function's body) rather than read back out of conn.assigns in the
  # rescue clause below -- def/2's implicit try wraps the whole function body, so a
  # variable/assign set inside that body (including conn.assigns) is invisible to its
  # own rescue clause and would raise a KeyError there instead of reporting the
  # original Prestige error.
  defp do_query(conn, _params, query_start_ms) do
    with {:ok, statement, conn} <- read_body(conn),
         {:ok, affected_models} <- QueryAccessUtils.get_affected_models(statement),
         {:ok, session} <- QueryAccessUtils.authorized_session(conn, affected_models),
         {:ok, rows, _} <-
           QueryCache.fetch_or_execute(statement, fn ->
             fetched =
               @prestige_impl.stream!(session, statement)
               |> Stream.flat_map(&@prestige_result_impl.as_maps/1)
               |> Enum.to_list()

             {:ok, fetched}
           end) do
      Logger.info("Query request - statement: #{inspect(statement)}, affected_models: #{length(affected_models)}")

      Enum.each(affected_models, fn model ->
        Brook.Event.send(DiscoveryApi.instance_name(), dataset_query(), __MODULE__, model.id)
      end)

      caller_id = Plug.Conn.get_req_header(conn, "api_key") |> List.first() || "anonymous"
      Task.start(fn -> DiscoveryApi.Stats.QueryStats.record_caller(caller_id) end)

      format = get_format(conn)

      data_stream = rows |> DiscoveryApi.Stats.QueryStats.wrap_stream(statement)

      rendered_data_stream = MultipleDataView.render_as_stream(:data, format, %{stream: data_stream})

      resp_as_stream(conn, rendered_data_stream, format)
    else
      {:error, :invalid_statement} ->
        Logger.error("Query failed - invalid statement")
        render_error(conn, 400, "Invalid SQL statement")

      {:error, :table_not_found} ->
        Logger.error("Query failed - table not found")
        render_error(conn, 400, "Table not found")

      {:error, "Query statement is invalid" <> _rest = error_msg} ->
        Logger.error("Query failed - #{error_msg}")
        render_error(conn, 400, "Bad Request")

      {:sql_error, error} ->
        duration_ms = System.monotonic_time(:millisecond) - query_start_ms
        Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:multi", duration_ms) end)
        Logger.error("Query failed - SQL error: #{inspect(error)}")
        render_error(conn, 400, error)

      {:error, "Session not authorized" = error_msg} ->
        Logger.error("Query failed - #{error_msg}")
        render_error(conn, 400, "Bad Request")

      {:error, reason} ->
        Logger.error("Query failed - error reading body or getting affected models, reason: #{inspect(reason)}")
        render_error(conn, 400, "Bad Request")

      other ->
        Logger.error("Query failed - unexpected error: #{inspect(other)}")
        render_error(conn, 400, "Bad Request")
    end
  rescue
    error in [Prestige.BadRequestError, Prestige.Error, Prestige.ConnectionError] ->
      duration_ms = System.monotonic_time(:millisecond) - query_start_ms
      Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:multi", duration_ms) end)
      Logger.error("Query failed - Prestige error: #{inspect(error)}, message: #{error.message}")
      render_error(conn, 400, PrestoService.sanitize_error(error.message, "Query Error"))
  end
end
