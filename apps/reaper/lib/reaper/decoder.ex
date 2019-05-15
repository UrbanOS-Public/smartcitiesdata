NimbleCSV.define(CsvParser, [])

defmodule Reaper.Decoder do
  @moduledoc false
  require Logger
  alias TransitRealtime.FeedMessage

  alias Reaper.ReaperConfig

  def decode(body, %ReaperConfig{sourceFormat: "gtfs"} = config) do
    try do
      message = FeedMessage.decode(body)
      message.entity
    rescue
      error ->
        yeet_error(config, body, error)
        []
    end
  end

  def decode(body, %ReaperConfig{sourceFormat: "json"} = config) do
    case Jason.decode(body) do
      {:ok, response} ->
        response

      {:error, error} ->
        yeet_error(config, body, error)
        []
    end
  end

  def decode({:file, filename}, %ReaperConfig{sourceFormat: "csv", schema: schema} = config) do
    try do
      keys = Enum.map(schema, fn el -> el.name end)

      filename
      |> File.stream!()
      |> Stream.reject(fn line -> String.trim(line) == "" end)
      |> CsvParser.parse_stream(skip_headers: false)
      |> Stream.map(fn row -> keys |> Enum.zip(row) |> Map.new() end)
    rescue
      error ->
        yeet_error(config, "DatasetId : #{config.dataset_id}", error)
        []
    end
  end

  def decode(body, %ReaperConfig{sourceFormat: other} = config) do
    yeet_error(config, body, %RuntimeError{message: "#{other} is an invalid format"})
    []
  end

  defp yeet_error(%ReaperConfig{dataset_id: dataset_id}, message, error) do
    Yeet.process_dead_letter(dataset_id, message, "Reaper", error: error)
  end
end
