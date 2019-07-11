defmodule DiscoveryApiWeb.DatasetDownloadController do
  use DiscoveryApiWeb, :controller
  alias DiscoveryApiWeb.DatasetMetricsService
  require Logger

  def fetch_file(conn, params) do
    if conn.assigns.model.sourceType == "host" do
      {:ok, %{"aws_access_key_id" => access_key, "aws_secret_access_key" => secret_key}} = DiscoveryApi.CredentialRetriever.retrieve()
      System.put_env("AWS_ACCESS_KEY_ID", access_key)
      System.put_env("AWS_SECRET_ACCESS_KEY", secret_key)
      fetch_file_from_s3(conn, get_format(conn))
    else
      fetch_file(conn, params, get_format(conn))
    end
  end

  def fetch_file(conn, _params, ["csv"]) do
    table = conn.assigns.model.systemName

    columns = fetch_columns(table)

    download(conn, conn.assigns.model.id, table, columns)
  end

  def fetch_file(conn, _params, ["json" = format]) do
    table = conn.assigns.model.systemName

    data =
      "select * from #{table}"
      |> Prestige.execute(rows_as_maps: true)
      |> Stream.map(&Jason.encode!/1)
      |> Stream.intersperse(",")

    DatasetMetricsService.record_api_hit("downloads", conn.assigns.model.id)

    [["["], data, ["]"]]
    |> Stream.concat()
    |> stream_data(conn, conn.assigns.model.id, format)
  end

  def fetch_file(conn, params, _unmatched_format) do
    fetch_file(conn, params, ["csv"])
  end

  def fetch_file_from_s3(conn, formats) do
    available_extension =
      formats
      |> Enum.find(fn extension ->
        file_exists(conn.assigns.model.organizationDetails.orgName, conn.assigns.model.id, extension)
      end)

    if available_extension do
      DatasetMetricsService.record_api_hit("downloads", conn.assigns.model.id)
      stream_from_s3(conn, available_extension)
    else
      conn
      |> render_error(406, "File not available in the specified format")
    end
  end

  def stream_from_s3(conn, format) do
    bucket_name()
    |> ExAws.S3.download_file(
      "/#{conn.assigns.model.organizationDetails.orgName}/#{conn.assigns.model.id}.#{format}",
      "dataset"
    )
    |> ExAws.stream!(region: region())
    |> stream_data(conn, "name", format)
  end

  defp file_exists(org_name, dataset_id, extension) do
    bucket_name()
    |> ExAws.S3.list_objects(prefix: "/#{org_name}/#{dataset_id}.#{extension}")
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
    |> stream_data(conn, dataset_id, "csv")
  end

  defp bucket_name() do
    Application.get_env(:discovery_api, :hosted_bucket)
  end

  defp region() do
    Application.get_env(:discovery_api, :hosted_region)
  end
end
