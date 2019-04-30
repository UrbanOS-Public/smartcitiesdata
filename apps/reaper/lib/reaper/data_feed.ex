defmodule Reaper.DataFeed do
  @moduledoc false

  alias Reaper.{Cache, Decoder, Extractor, Loader, UrlBuilder, Persistence, ReaperConfig}

  def process(%ReaperConfig{} = config, cache) do
    generated_time_stamp = DateTime.utc_now()

    config
    |> UrlBuilder.build()
    |> Extractor.extract(config.sourceFormat)
    |> Decoder.decode(config)
    |> Stream.map(&Cache.mark_duplicates(cache, &1))
    |> Stream.reject(&duplicate?/1)
    |> Stream.map(&load(&1, config, generated_time_stamp))
    |> Stream.map(&cache(&1, cache))
    |> record_last_fetched_timestamp(config.dataset_id, generated_time_stamp)
  end

  defp duplicate?({:duplicate, _message}), do: true
  defp duplicate?(_), do: false

  defp cache({:ok, message}, cache) do
    case Cache.cache(cache, message) do
      {:ok, _} -> {:ok, message}
      result -> result
    end
  end

  defp cache({:error, _} = error, _cache), do: error

  defp load({:ok, message}, config, time_stamp) do
    case Loader.load(message, config, time_stamp) do
      :ok -> {:ok, message}
      result -> result
    end
  end

  defp load({:error, _} = error, _config, _time_stamp), do: error

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
