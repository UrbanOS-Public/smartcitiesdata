defmodule Reaper.Decoder do
  @moduledoc false
  require Logger
  alias TransitRealtime.FeedMessage
  @dlq_topic Application.get_env(:yeet, :topic)

  def decode(body, "gtfs", _schema) do
    try do
      message = FeedMessage.decode(body)
      message.entity
    rescue
      error ->
        yeet_error(body, error)
        []
    end
  end

  def decode(body, "json", _schema) do
    case Jason.decode(body) do
      {:ok, response} ->
        response

      {:error, error} ->
        yeet_error(body, error)
        []
    end
  end

  def decode(body, "csv", schema) do
    try do
      keys = Enum.map(schema, fn el -> el.name end)

      body
      |> String.trim()
      |> String.split("\n")
      |> CSV.decode!(headers: keys, strip_fields: true)
      |> Enum.to_list()
    rescue
      error ->
        yeet_error(body, error)
        []
    end
  end

  defp yeet_error(message, error) do
    Logger.warn("Unable to decode message; re-routing to DLQ topic '#{@dlq_topic}'")
    Yeet.process_dead_letter(message, "Reaper", exit_code: error)
  end
end
