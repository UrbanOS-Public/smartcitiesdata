defmodule Reaper.Decoder.Gtfs do
  @moduledoc """
  Decoder implementation that will decode the file as GTFS
  """
  alias TransitRealtime.FeedMessage

  @behaviour Reaper.Decoder

  @impl Reaper.Decoder
  def decode({:file, filename}, _ingestion) do
    bytes = File.read!(filename)

    try do
      message = feed_message_decoder().decode(bytes)
      {:ok, message.entity}
    rescue
      error ->
        {:error, bytes, error}
    end
  end
  
  defp feed_message_decoder do
    Application.get_env(:reaper, :feed_message_decoder, FeedMessage)
  end

  @impl Reaper.Decoder
  def handle?(source_format) do
    String.downcase(source_format) == "application/gtfs+protobuf"
  end
end
