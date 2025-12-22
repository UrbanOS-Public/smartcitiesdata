defmodule DiscoveryApiWeb.MultipleDataController do
  use DiscoveryApiWeb, :controller
  require Logger
  alias DiscoveryApiWeb.MultipleDataView
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApi.Services.PrestoService
  import DiscoveryApiWeb.Utilities.StreamUtils

  import SmartCity.Event,
    only: [dataset_query: 0]

  @prestige_impl Application.compile_env(:discovery_api, :prestige, Prestige)
  @prestige_result_impl Application.compile_env(:discovery_api, :prestige_result, Prestige.Result)

  plug(:accepts, MultipleDataView.accepted_formats())

  def query(conn, _params) do
    with {:ok, statement, conn} <- read_body(conn),
         {:ok, affected_models} <- QueryAccessUtils.get_affected_models(statement),
         {:ok, session} <- QueryAccessUtils.authorized_session(conn, affected_models) do
      Logger.info("Query request - statement: #{inspect(statement)}, affected_models: #{length(affected_models)}")

      Enum.each(affected_models, fn model ->
        Brook.Event.send(DiscoveryApi.instance_name(), dataset_query(), __MODULE__, model.id)
      end)

      format = get_format(conn)

      data_stream =
        @prestige_impl.stream!(session, statement)
        |> Stream.flat_map(&@prestige_result_impl.as_maps/1)

      rendered_data_stream = MultipleDataView.render_as_stream(:data, format, %{stream: data_stream})

      resp_as_stream(conn, rendered_data_stream, format)
    else
      {:error, :invalid_statement} ->
        Logger.error("Query failed - invalid statement")
        render_error(conn, 400, "Invalid SQL statement")

      {:error, :table_not_found} ->
        Logger.error("Query failed - table not found")
        render_error(conn, 400, "Table not found")

      {:sql_error, error} ->
        Logger.error("Query failed - SQL error: #{inspect(error)}")
        render_error(conn, 400, error)

      {:error, reason} ->
        Logger.error("Query failed - error reading body or getting affected models, reason: #{inspect(reason)}")
        render_error(conn, 400, "Bad Request: #{inspect(reason)}")

      other ->
        Logger.error("Query failed - unexpected error: #{inspect(other)}")
        render_error(conn, 400, "Bad Request")
    end
  rescue
    error in [Prestige.BadRequestError, Prestige.Error] ->
      Logger.error("Query failed - Prestige error: #{inspect(error)}, message: #{error.message}")
      render_error(conn, 400, PrestoService.sanitize_error(error.message, "Query Error"))
  end
end
