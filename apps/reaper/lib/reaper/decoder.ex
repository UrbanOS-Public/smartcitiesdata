defmodule Reaper.Decoder do
  @moduledoc false
  alias TransitRealtime.FeedMessage

  def decode(body, "gtfs") do
    message =
      body
      |> FeedMessage.decode()

    message.entity
  end

  def decode(body, "json") do
    body
    |> Jason.decode!()
  end

  def decode(body, "csv") do
    body
    |> String.trim()
    |> String.split("\n")
    |> CSV.decode!(headers: true, strip_fields: true)
    |> Enum.to_list()
  end
end
