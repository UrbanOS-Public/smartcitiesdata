NimbleCSV.define(CsvParser, [])

defmodule Reaper.Decoder.Csv do
  @moduledoc """
  Reaper.Decoder implementation to decode a csv file into a stream of records
  """

  defmodule CsvError do
    defexception [:message]
  end

  alias Reaper.ReaperConfig

  @behaviour Reaper.Decoder

  @impl Reaper.Decoder
  def decode({:file, filename}, %ReaperConfig{schema: schema} = config) do
    try do
      keys = Enum.map(schema, fn el -> el.name end)

      stream =
        filename
        |> File.stream!()
        |> Stream.reject(fn line -> String.trim(line) == "" end)
        |> CsvParser.parse_stream(skip_headers: false)
        |> Stream.map(fn row -> keys |> Enum.zip(row) |> Map.new() end)

      {:ok, stream}
    rescue
      error ->
        {:error, "DatasetId: #{config.dataset_id}", error}
    end
  end

  @impl Reaper.Decoder
  def handle?(source_format) do
    String.downcase(source_format) == "csv"
  end
end
