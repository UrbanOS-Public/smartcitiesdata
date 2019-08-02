defmodule Reaper.Decoder.Json do
  @moduledoc """
  Decoder implementation that will decode the file as JSON
  """
  @behaviour Reaper.Decoder

  @impl Reaper.Decoder
  def decode({:file, filename}, _config) do
    data = File.read!(filename)

    case Jason.decode(data) do
      {:ok, response} ->
        {:ok, List.wrap(response)}

      {:error, error} ->
        {:error, data, error}
    end
  end

  @impl Reaper.Decoder
  def handle?(source_format) when is_binary(source_format) do
    String.downcase(source_format) == "json"
  end

  def handle?(_source_format), do: false
end
