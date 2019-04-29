defmodule Reaper.DataFeed do
  @moduledoc false

  alias Reaper.{Cache, Decoder, Extractor, Loader, UrlBuilder, Persistence, ReaperConfig}

  def process(%ReaperConfig{} = config, cache) do
    generated_time_stamp = DateTime.utc_now()

    config
    |> UrlBuilder.build()
    |> Extractor.extract(config.sourceFormat)
    |> Decoder.decode(config)
    |> Stream.reject(&Cache.duplicate?(&1, cache))
    |> Stream.map(&Loader.load(&1, config, generated_time_stamp))
    |> Cache.cache(cache)
    |> record_last_fetched_timestamp(config.dataset_id, generated_time_stamp)
  end

  defp record_last_fetched_timestamp([], dataset_id, timestamp) do
    Persistence.record_last_fetched_timestamp(dataset_id, timestamp)
  end

  defp record_last_fetched_timestamp(records, dataset_id, timestamp) do
    if any_successful?(records) do
      Persistence.record_last_fetched_timestamp(dataset_id, timestamp)
    end
  end

  defp any_successful?(records) do
    Enum.reduce(records, false, fn {status, _}, acc ->
      case status do
        :ok -> true
        _ -> acc
      end
    end)
  end
end
