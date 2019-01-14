defmodule DiscoveryApiWeb.DatasetQueryService do
  alias DiscoveryApiWeb.KyloService
  alias DiscoveryApi.Data.Thrive

  def get_thrive_stream(dataset_id, opts \\ []) do
    query_string = Keyword.get(opts, :query_string, "")
    columns = Keyword.get(opts, :columns, ["*"])

    with {:ok, table, schema, table_headers} <- get_table_and_headers(dataset_id),
         hive_query <- "select #{Enum.join(columns, ",")} from #{schema}.#{table} #{query_string}",
         chunk_size <- 1000,
         {:ok, stream} <- Thrive.stream_results(hive_query, chunk_size) do
      {:ok, stream, %{table: table, table_headers: table_headers}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def get_table_and_headers(dataset_id) do
    with {:ok, metadata} <- KyloService.fetch_dataset_metadata(dataset_id),
         {schema, table} <- extract_schema_and_table(metadata),
         {:ok, description} <- KyloService.fetch_table_schema(schema, table),
         table_headers <- extract_table_headers(description) do
      {:ok, table, schema, table_headers}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def map_data_stream_to_obj(stream, table_headers, dataset_id) do
    stream
    |> Stream.map(&Tuple.to_list(&1))
    |> Stream.map(&Enum.zip(table_headers, &1))
    |> Stream.map(&Enum.reduce(&1, %{}, fn {key, value}, map -> Map.put(map, key, value) end))
    |> Enum.to_list()
    |> (fn data ->
          %{
            content: %{
              id: dataset_id,
              columns: table_headers,
              data: data
            }
          }
        end).()
  end

  def map_data_stream_for_csv(stream, table_headers) do
    stream
    |> Stream.map(&Tuple.to_list(&1))
    |> (fn stream -> Stream.concat([table_headers], stream) end).()
    |> CSV.encode(delimiter: "\n")
  end

  defp extract_schema_and_table(metadata) do
    %{
      "systemName" => table,
      "category" => %{
        "systemName" => schema
      }
    } = metadata

    {schema, table}
  end

  defp extract_table_headers(%{"fields" => fields}) do
    Enum.map(fields, &Map.get(&1, "name"))
  end
end
