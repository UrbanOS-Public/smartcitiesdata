defmodule DiscoveryApiWeb.DataController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Services.{PrestoService, ObjectStorageService}
  alias DiscoveryApiWeb.Plugs.{GetModel, Restrictor, RecordMetrics}
  alias DiscoveryApiWeb.DataView
  alias DiscoveryApiWeb.Utilities.AuthUtils
  alias DiscoveryApiWeb.Utilities.JsonFieldDecoder
  require Logger

  plug GetModel
  plug :conditional_accepts, DataView.accepted_formats() when action in [:fetch_file]
  plug :accepts, DataView.accepted_formats() when action in [:query]
  plug :accepts, DataView.accepted_preview_formats() when action in [:fetch_preview]
  plug Restrictor
  plug RecordMetrics, fetch_file: "downloads", query: "queries"

  defp conditional_accepts(conn, formats) do
    if conn.assigns.model.sourceType == "host" do
      DiscoveryApiWeb.Plugs.Acceptor.call(conn, [])
    else
      Phoenix.Controller.accepts(conn, formats)
    end
  end

  def fetch_preview(conn, _params) do
    dataset_name = conn.assigns.model.systemName
    columns = PrestoService.preview_columns(dataset_name)
    rows = PrestoService.preview(dataset_name)
    schema = conn.assigns.model.schema
    decoded_rows = JsonFieldDecoder.ensure_decoded(rows, schema)

    render(conn, :data, %{rows: decoded_rows, columns: columns, dataset_name: dataset_name})
  rescue
    Prestige.Error -> render(conn, :data, %{rows: [], columns: []})
  end

  def fetch_file(conn, params) do
    fetch_file(conn, params, get_format(conn))
  end

  def fetch_file(conn, _params, possible_extensions) when is_list(possible_extensions) do
    model = conn.assigns.model
    dataset_id = model.id
    path = "#{model.organizationDetails.orgName}/#{model.name}"

    case ObjectStorageService.download_file_as_stream(path, possible_extensions) do
      {:ok, data_stream, extension} ->
        resp_as_stream(conn, data_stream, extension, dataset_id, true)

      _ ->
        render_error(conn, 406, "File not available in the specified format")
    end
  end

  def fetch_file(conn, _params, format) do
    dataset_name = conn.assigns.model.systemName
    dataset_id = conn.assigns.model.id
    columns = PrestoService.preview_columns(dataset_name)
    schema = conn.assigns.model.schema

    data_stream = Prestige.execute("select * from #{dataset_name}", rows_as_maps: true)

    rendered_data_stream =
      DataView.render_as_stream(:data, format, %{stream: data_stream, columns: columns, dataset_name: dataset_name, schema: schema})

    resp_as_stream(conn, rendered_data_stream, format, dataset_id)
  end

  def query(conn, params) do
    format = get_format(conn)
    dataset_name = conn.assigns.model.systemName
    dataset_id = conn.assigns.model.id
    current_user = conn.assigns.current_user
    schema = conn.assigns.model.schema

    with {:ok, columns} <- PrestoService.get_column_names(dataset_name, Map.get(params, "columns")),
         {:ok, query} <- PrestoService.build_query(params, dataset_name),
         true <- AuthUtils.authorized_to_query?(query, current_user) do
      data_stream = Prestige.execute(query, rows_as_maps: true)

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
end
