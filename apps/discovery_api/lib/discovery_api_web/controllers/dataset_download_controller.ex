require Logger

defmodule DiscoveryApiWeb.DatasetDownloadController do
  @moduledoc false
  use DiscoveryApiWeb, :controller
  alias DiscoveryApi.Data.Dataset
  alias DiscoveryApiWeb.DatasetMetricsService

  def fetch_presto(conn, params) do
    fetch_presto(conn, params, get_format(conn))
  end

  def fetch_presto(conn, %{"dataset_id" => dataset_id}, "csv") do
    table =
      dataset_id
      |> Dataset.get()
      |> fetch_table()

    columns = fetch_columns(table)

    download(conn, dataset_id, table, columns)
  end

  def fetch_presto(conn, %{"dataset_id" => dataset_id}, "json") do
    table =
      dataset_id
      |> Dataset.get()
      |> fetch_table()

    data =
      "select * from #{table}"
      |> Prestige.execute(rows_as_maps: true)
      |> Stream.map(&Jason.encode!/1)
      |> Stream.intersperse(",")

    DatasetMetricsService.record_api_hit("downloads", dataset_id)

    [["["], data, ["]"]]
    |> Stream.concat()
    |> stream_data(conn, dataset_id, get_format(conn))
  end

  defp fetch_table(nil), do: nil
  defp fetch_table(dataset), do: dataset.systemName

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
end
