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
  def decode({:file, filename}, %SmartCity.Ingestion{schema: schema} = ingestion) do
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
        {:error, "IngestionId: #{ingestion.id}", error}
    end
  end

  defp header?(row, keys) do
    keys
    |> Enum.zip(row)
    |> Enum.all?(&header_equals?(&1))
  end

  defp header_equals?({key, val}) do
    key |> cleanse() == val |> cleanse()
  end

  defp cleanse(text) do
    text |> String.trim() |> String.downcase()
  end

  @impl Reaper.Decoder
  def handle?(source_format) do
    String.downcase(source_format) == "text/csv"
  end
end
