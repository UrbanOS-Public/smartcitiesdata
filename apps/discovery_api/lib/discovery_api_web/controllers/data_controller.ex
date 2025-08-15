defmodule DiscoveryApiWeb.DataController do
  use DiscoveryApiWeb, :controller
  use Properties, otp_app: :discovery_api

  alias DiscoveryApi.Services.PrestoService
  alias DiscoveryApiWeb.Plugs.{GetModel, Restrictor, RecordMetrics}
  alias DiscoveryApiWeb.DataView
  alias DiscoveryApiWeb.Utilities.QueryAccessUtils
  alias DiscoveryApiWeb.Utilities.HmacToken
  require Logger

  # Allow configuring service modules for testing
  @presto_service_impl Application.compile_env(:discovery_api, :presto_service, PrestoService)
  @prestige_impl Application.compile_env(:discovery_api, :prestige, Prestige)
  @prestige_result_impl Application.compile_env(:discovery_api, :prestige_result, Prestige.Result)
  @hmac_token_impl Application.compile_env(:discovery_api, :hmac_token, DiscoveryApiWeb.Utilities.HmacToken)
  @date_time_impl Application.compile_env(:discovery_api, :date_time, DateTime)

  plug(GetModel)
  plug(:conditional_accepts, DataView.accepted_formats() when action in [:fetch_file])
  plug(:accepts, DataView.accepted_formats() when action in [:query])
  plug(:accepts, DataView.accepted_preview_formats() when action in [:fetch_preview])
  plug(Restrictor)
  plug(RecordMetrics, query: "queries")

  getter(:download_link_expire_seconds, generic: true)

  defp conditional_accepts(conn, formats) do
    if conn.assigns.model.sourceType == "host" do
      DiscoveryApiWeb.Plugs.Acceptor.call(conn, [])
    else
      Phoenix.Controller.accepts(conn, formats)
    end
  end

  def fetch_preview(conn, _params) do
    session =
      DiscoveryApi.prestige_opts()
      |> @prestige_impl.new_session()

    dataset_name = conn.assigns.model.systemName
    schema = conn.assigns.model.schema

    columns = @presto_service_impl.preview_columns(schema)
    rows = @presto_service_impl.preview(session, dataset_name, schema)

    render(conn, :data, %{
      rows: rows,
      columns: columns,
      dataset_name: dataset_name,
      schema: schema
    })
  rescue
    error in Prestige.Error ->
      Logger.error("Fetch Preview encountered an error: #{inspect(error)}")
      render(conn, :data, %{rows: [], columns: [], schema: []})
  end

  def download_presigned_url(conn, params) do
    ## Potential issue
    expires_in_seconds = download_link_expire_seconds()
    expires = @date_time_impl.utc_now() |> DateTime.add(expires_in_seconds, :second) |> DateTime.to_unix()
    hmac_token = @hmac_token_impl.create_hmac_token(params["dataset_id"], expires)
    scheme = Application.get_env(:discovery_api, DiscoveryApiWeb.Endpoint)[:url][:scheme]
    host = Application.get_env(:discovery_api, DiscoveryApiWeb.Endpoint)[:url][:host]
    base_url = scheme <> "://" <> host

    json(
      conn,
      base_url <> "/api/v1/dataset/#{params["dataset_id"]}/download?key=#{hmac_token}&expires=#{expires}"
    )
  end

  def query(conn, params) do
    format = get_format(conn)
    dataset_name = conn.assigns.model.systemName
    dataset_id = conn.assigns.model.id
    current_user = conn.assigns.current_user
    schema = conn.assigns.model.schema
    session = DiscoveryApi.prestige_opts() |> @prestige_impl.new_session()
    api_key = Plug.Conn.get_req_header(conn, "api_key")

    with {:ok, columns} <- @presto_service_impl.get_column_names(session, dataset_name, Map.get(params, "columns")),
         {:ok, query} <- @presto_service_impl.build_query(params, dataset_name, columns, schema),
         {:ok, affected_models} <- QueryAccessUtils.get_affected_models(query),
         true <- QueryAccessUtils.user_is_authorized?(affected_models, current_user, api_key) do
      data_stream =
        session
        |> @prestige_impl.stream!(query)
        |> Stream.flat_map(&@prestige_result_impl.as_maps/1)
        |> map_schema?(schema, format)

      rendered_data_stream =
        DataView.render_as_stream(:data, format, %{stream: data_stream, columns: columns, dataset_name: dataset_name, schema: schema})

      resp_as_stream(conn, rendered_data_stream, format, dataset_id)
    else
      {:error, error} ->
        render_error(conn, 404, error)

      _ ->
        render_error(conn, 400, "Bad Request")
    end
  end

  defp map_schema?(data, schema, format) do
    if format == "json" || format == "geojson", do: PrestoService.map_prestige_results_to_schema(data, schema), else: data
  end
end
