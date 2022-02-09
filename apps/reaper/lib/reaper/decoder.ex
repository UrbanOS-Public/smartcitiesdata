defmodule Reaper.Decoder do
  @moduledoc """
  This module decodes datasets of different types into JSON
  """
  require Logger

  @type filename :: String.t()
  @type format :: String.t()
  @type reason :: any()
  @type data :: any()

  @callback decode({:file, filename()}, %SmartCity.Ingestion{}) ::
              {:ok, Enumerable.t()} | {:error, data(), reason()}
  @callback handle?(format()) :: boolean()

  @implementations [
    Reaper.Decoder.Gtfs,
    Reaper.Decoder.Json,
    Reaper.Decoder.Csv,
    Reaper.Decoder.Xml,
    Reaper.Decoder.GeoJson,
    Reaper.Decoder.Unknown
  ]

  @doc """
  Converts a dataset into JSON based on it's `sourceFormat`
  """
  def decode({:file, filename}, %SmartCity.Ingestion{sourceFormat: source_format} = ingestion) do
    response =
      @implementations
      |> Enum.find(&handle?(&1, source_format))
      |> apply(:decode, [{:file, filename}, ingestion])

    case response do
      {:ok, data} ->
        data

      {:error, data, reason} ->
        throw_error(ingestion, data, reason)
        raise reason
    end
  end

  defp handle?(implementation, source_format) do
    apply(implementation, :handle?, [source_format])
  end

  defp throw_error(%SmartCity.Ingestion{targetDataset: dataset_id}, message, error) do
    DeadLetter.process(dataset_id, message, "reaper", error: error)
  end
end
