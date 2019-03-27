defmodule Reaper.Decoder do
  @moduledoc false
  alias TransitRealtime.FeedMessage

  def decode(body, "gtfs", _schema) do
    message =
      body
      |> FeedMessage.decode()

    message.entity
  end

  def decode(body, "json", _schema) do
    body
    |> Jason.decode!()
  end

  def decode(body, "csv", schema) do
    keys = Enum.map(schema, fn el -> el.name end)

    body
    |> String.trim()
    |> String.split("\n")
    |> CSV.decode!(headers: keys, strip_fields: true)
    |> Enum.to_list()
  end
end
