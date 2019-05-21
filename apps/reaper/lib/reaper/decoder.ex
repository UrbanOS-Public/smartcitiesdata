defmodule Reaper.Decoder do
  @moduledoc """
  Decodes files from various source formats
  """
  require Logger

  alias Reaper.ReaperConfig

  @type filename :: String.t()
  @type format :: String.t()
  @type reason :: any()
  @type data :: any()

  @callback decode({:file, filename()}, %ReaperConfig{}) :: {:ok, Enumerable.t()} | {:error, data(), reason()}
  @callback handle?(format()) :: boolean()

  @implementations [
    Reaper.Decoder.Gtfs,
    Reaper.Decoder.Json,
    Reaper.Decoder.Csv,
    Reaper.Decoder.Unknown
  ]

  def decode({:file, filename}, %ReaperConfig{sourceFormat: source_format} = config) do
    response =
      @implementations
      |> Enum.find(&handle?(&1, source_format))
      |> apply(:decode, [{:file, filename}, config])

    case response do
      {:ok, data} ->
        data

      {:error, data, reason} ->
        yeet_error(config, data, reason)
        raise reason
    end
  end

  defp handle?(implementation, source_format) do
    apply(implementation, :handle?, [source_format])
  end

  defp yeet_error(%ReaperConfig{dataset_id: dataset_id}, message, error) do
    Yeet.process_dead_letter(dataset_id, message, "Reaper", error: error)
  end
end
