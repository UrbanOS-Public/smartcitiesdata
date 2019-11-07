defmodule Reaper.Decoder do
  @moduledoc """
  This module decodes datasets of different types into JSON
  """
  require Logger

  @type filename :: String.t()
  @type format :: String.t()
  @type reason :: any()
  @type data :: any()

  @callback decode({:file, filename()}, %SmartCity.Dataset{}) ::
              {:ok, Enumerable.t()} | {:error, data(), reason()}
  @callback handle?(format()) :: boolean()

  @implementations [
    Reaper.Decoder.Gtfs,
    Reaper.Decoder.Json,
    Reaper.Decoder.Csv,
    Reaper.Decoder.GeoJson,
    Reaper.Decoder.Unknown
  ]

  @doc """
  Converts a dataset into JSON based on it's `sourceFormat`
  """
  def decode({:file, filename}, %SmartCity.Dataset{technical: %{sourceFormat: source_format}} = dataset) do
    response =
      @implementations
      |> Enum.find(&handle?(&1, source_format))
      |> apply(:decode, [{:file, filename}, dataset])

    case response do
      {:ok, data} ->
        data

      {:error, data, reason} ->
        yeet_error(dataset, data, reason)
        raise reason
    end
  end

  defp handle?(implementation, source_format) do
    apply(implementation, :handle?, [source_format])
  end

  defp yeet_error(%SmartCity.Dataset{id: dataset_id}, message, error) do
    Yeet.process_dead_letter(dataset_id, message, "Reaper", error: error)
  end
end
