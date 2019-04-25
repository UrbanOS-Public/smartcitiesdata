NimbleCSV.define(CsvParser, [])

defmodule Reaper.Decoder do
  @moduledoc false
  require Logger
  alias TransitRealtime.FeedMessage

  alias Reaper.ReaperConfig

  def decode(body, %ReaperConfig{sourceFormat: "gtfs"}) do
    try do
      message = FeedMessage.decode(body)
      message.entity
    rescue
      error ->
        yeet_error(body, error)
        []
    end
  end

  def decode(body, %ReaperConfig{sourceFormat: "json"}) do
    case Jason.decode(body) do
      {:ok, response} ->
        response

      {:error, error} ->
        yeet_error(body, error)
        []
    end
  end

  def decode({:file, filename}, %ReaperConfig{sourceFormat: "csv", dataset_id: dataset_id, schema: schema}) do
    try do
      keys = Enum.map(schema, fn el -> el.name end)

      filename
      |> File.stream!()
      |> setup_after_hook_for_deletion(filename)
      |> Stream.reject(fn line -> String.trim(line) == "" end)
      |> CsvParser.parse_stream(skip_headers: false)
      |> Stream.map(fn row -> keys |> Enum.zip(row) |> Map.new() end)
    rescue
      error ->
        yeet_error("DatasetId : #{dataset_id}", error)
        []
    end
  end

  def decode(body, %ReaperConfig{sourceFormat: other}) do
    yeet_error(body, %RuntimeError{message: "#{other} is an invalid format"})
    []
  end

  defp yeet_error(message, error) do
    dlq_topic = Application.get_env(:yeet, :topic)
    Logger.warn("Unable to decode message; re-routing to DLQ topic '#{dlq_topic}'")
    Yeet.process_dead_letter(message, "Reaper", exit_code: error)
  end

  defp setup_after_hook_for_deletion(stream, filename) do
    Stream.resource(
      fn -> :init end,
      fn state ->
        case state do
          :init -> {stream, :done}
          :done -> {:halt, :done}
        end
      end,
      fn _ -> File.rm(filename) end
    )
  end
end
