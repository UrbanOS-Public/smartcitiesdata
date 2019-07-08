defmodule DiscoveryApiWeb.DatasetDownloadController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.DatasetMetricsService
  require Logger

  def fetch_file(conn, params) do
    fetch_file(conn, params, get_format(conn))
  end

  def fetch_file(conn, _params, "csv") do
    table = conn.assigns.model.systemName

    columns = fetch_columns(table)

    download(conn, conn.assigns.model.id, table, columns)
  end

  def fetch_file(conn, _params, "json") do
    table = conn.assigns.model.systemName

    data =
      "select * from #{table}"
      |> Prestige.execute(rows_as_maps: true)
      |> Stream.map(&Jason.encode!/1)
      |> Stream.intersperse(",")

    DatasetMetricsService.record_api_hit("downloads", conn.assigns.model.id)

    [["["], data, ["]"]]
    |> Stream.concat()
    |> stream_data(conn, conn.assigns.model.id, get_format(conn))
  end

  def fetch_file(conn, _params, _format) do
    available_extension =
      conn.assigns.accepted_extensions
      |> Enum.find(fn extension ->
        file_exists(conn.assigns.model.organizationDetails.orgName, conn.assigns.model.id, extension)
      end)
      |> IO.inspect(label: "dataset_download_controller.ex:39")

    if available_extension do
      ExAws.S3.download_file(
        bucket_name(),
        "/#{conn.assigns.model.organizationDetails.orgName}/#{conn.assigns.model.id}.#{available_extension}",
        "dataset"
      )
      |> ExAws.stream!(region: "us-east-2")
      |> stream_data(conn, "name", get_format(conn))
    else
      conn
      |> render_error(406, "File not available in the specified format")
    end
  rescue
    e ->
      Logger.error("Error trying to download a hosted file: #{inspect(e)}")
      raise e
  end

  defp file_exists(org_name, dataset_id, extension) do
    ExAws.S3.list_objects(bucket_name(),
      prefix: "/#{org_name}/#{dataset_id}.#{extension}"
    )
    |> ExAws.request!()
    |> Map.get(:body)
    |> Map.get(:contents)
    |> length() > 0
  end

  defp fetch_columns(nil), do: nil

  defp fetch_columns(table) do
    "describe #{table}"
    |> Prestige.execute()
    |> Prestige.prefetch()
    |> Enum.map(fn [col | _tail] -> col end)
  end

  defp download(_conn, _id, _table_name, nil), do: nil

  defp download(conn, dataset_id, table, columns) do
    DatasetMetricsService.record_api_hit("downloads", dataset_id)

    "select * from #{table}"
    |> Prestige.execute()
    |> map_data_stream_for_csv(columns)
    |> stream_data(conn, dataset_id, get_format(conn))
  end

  defp bucket_name() do
    Application.get_env(:discovery_api, :hosted_bucket)
  end
end
