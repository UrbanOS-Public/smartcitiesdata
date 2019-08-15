defmodule DiscoveryApi.DatasetQueryService do
  @moduledoc false
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
end
