NimbleCSV.define(CsvParser, [])

defmodule Reaper.Decoder.Csv do
  @moduledoc """
  Reaper.Decoder implementation to decode a csv file into a stream of records
  """

  defmodule CsvError do
    defexception [:message]
  end

  @behaviour Reaper.Decoder

  @impl Reaper.Decoder
  def decode({:file, filename}, %SmartCity.Dataset{technical: %{schema: schema}} = dataset) do
    try do
      keys = Enum.map(schema, fn el -> el.name end)

      stream =
        filename
        |> File.stream!()
        |> Stream.reject(fn line -> String.trim(line) == "" end)
        |> CsvParser.parse_stream(skip_headers: false)
        |> Stream.reject(&header?(&1, keys))
        |> Stream.map(fn row -> keys |> Enum.zip(row) |> Map.new() end)

      {:ok, stream}
    rescue
      error ->
        {:error, "DatasetId: #{dataset.id}", error}
    end
  end

  defp header?(row, keys) do
    keys
    |> Enum.zip(row)
    |> Enum.all?(fn {key, val} -> key == String.trim(val) end)
  end

  @impl Reaper.Decoder
  def handle?(source_format) do
    String.downcase(source_format) == "text/csv"
  end
end
