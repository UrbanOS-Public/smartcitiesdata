defmodule Reaper.DataFeed do
  @moduledoc false

  alias Reaper.{Cache, Decoder, Extractor, Loader, UrlBuilder, Persistence, ReaperConfig}

  def process(%ReaperConfig{} = config, cache) do
    generated_time_stamp = DateTime.utc_now()

    config
    |> UrlBuilder.build()
    |> Extractor.extract(config.sourceFormat)
    |> Decoder.decode(config)
    |> RailStream.map(&Cache.mark_duplicates(cache, &1))
    |> RailStream.reject(&duplicate?/1)
    |> RailStream.map(&load(&1, config, generated_time_stamp))
    |> RailStream.map(&cache(&1, cache))
    |> RailStream.each_error(&report_errors(&1, &2, config))
    |> record_last_fetched_timestamp(config.dataset_id, generated_time_stamp)
  end

  defp duplicate?({:duplicate, _message}), do: true
  defp duplicate?(_), do: false

  defp report_errors(reason, message, config) do
    Yeet.process_dead_letter(config.dataset_id, message, "reaper", reason: inspect(reason))
  end

  defp cache(message, cache) do
    case Cache.cache(cache, message) do
      {:ok, _} -> {:ok, message}
      result -> result
    end
  end

  defp load(message, config, time_stamp) do
    case Loader.load(message, config, time_stamp) do
      :ok -> {:ok, message}
      result -> result
    end
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
