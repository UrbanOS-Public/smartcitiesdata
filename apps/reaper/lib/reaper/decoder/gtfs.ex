defmodule Reaper.Decoder.Gtfs do
  @moduledoc """
  Decoder implementation that will decode the file as GTFS
  """
  alias TransitRealtime.FeedMessage

  @behaviour Reaper.Decoder

  @impl Reaper.Decoder
  def decode({:file, filename}, _config) do
    bytes = File.read!(filename)

    try do
      message = FeedMessage.decode(bytes)
      {:ok, message.entity}
    rescue
      error ->
        {:error, bytes, error}
    end
  end

  @impl Reaper.Decoder
  def handle?(source_format) do
    String.downcase(source_format) == "gtfs"
  end
end
