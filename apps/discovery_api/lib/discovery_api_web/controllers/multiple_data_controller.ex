defmodule DiscoveryApiWeb.MultipleDataController do
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApiWeb.MultipleDataView
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApi.Services.{PrestoService, QueryCache}
  import DiscoveryApiWeb.Utilities.StreamUtils

  import SmartCity.Event,
    only: [dataset_query: 0]

  plug(:accepts, MultipleDataView.accepted_formats())

  def query(conn, _params) do
    conn = assign(conn, :query_start_ms, System.monotonic_time(:millisecond))

    with {:ok, statement, conn} <- read_body(conn),
         {:ok, affected_models} <- QueryAccessUtils.get_affected_models(statement),
         {:ok, session} <- QueryAccessUtils.authorized_session(conn, affected_models),
         {:ok, rows, _} <- QueryCache.fetch_or_execute(statement, fn ->
           fetched =
             Prestige.stream!(session, statement)
             |> Stream.flat_map(&Prestige.Result.as_maps/1)
             |> Enum.to_list()
           {:ok, fetched}
         end) do
      caller_id = Plug.Conn.get_req_header(conn, "api_key") |> List.first() || "anonymous"
      Task.start(fn -> DiscoveryApi.Stats.QueryStats.record_caller(caller_id) end)

      Enum.each(affected_models, fn model ->
        Brook.Event.send(DiscoveryApi.instance_name(), dataset_query(), __MODULE__, model.id)
      end)

      format = get_format(conn)

      data_stream = rows |> DiscoveryApi.Stats.QueryStats.wrap_stream(statement)

      rendered_data_stream = MultipleDataView.render_as_stream(:data, format, %{stream: data_stream})

      resp_as_stream(conn, rendered_data_stream, format)
    else
      {:sql_error, error} ->
        duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms
        Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:multi", duration_ms) end)
        render_error(conn, 400, error)

      _ ->
        render_error(conn, 400, "Bad Request")
    end
  rescue
    error in [Prestige.BadRequestError, Prestige.Error, Prestige.ConnectionError] ->
      duration_ms = System.monotonic_time(:millisecond) - conn.assigns.query_start_ms
      Task.start(fn -> DiscoveryApi.Stats.QueryStats.record("failed:multi", duration_ms) end)
      render_error(conn, 400, PrestoService.sanitize_error(error.message, "Query Error"))
  end
end
