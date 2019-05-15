defmodule Reaper.DataFeed do
  @moduledoc false

  alias Reaper.{Cache, Decoder, Extractor, Loader, UrlBuilder, Persistence, ReaperConfig, Persistence}

  def process(%ReaperConfig{} = config, cache) do
    generated_time_stamp = DateTime.utc_now()

    config
    |> UrlBuilder.build()
    |> Extractor.extract(config.dataset_id, config.sourceType)
    |> Decoder.decode(config)
    |> Stream.with_index()
    |> RailStream.map(&mark_duplicates(cache, &1))
    |> RailStream.reject(&duplicate?/1)
    |> RailStream.map(&mark_processed(config, &1))
    |> RailStream.reject(&index_processed?/1)
    |> RailStream.map(&load(&1, config, generated_time_stamp))
    |> RailStream.map(&save_last_processed_index(&1, config))
    |> RailStream.map(&cache(&1, cache))
    |> RailStream.each_error(&report_errors(&1, &2, config))
    |> record_last_fetched_timestamp(config.dataset_id, generated_time_stamp)

    Persistence.remove_last_processed_index(config.dataset_id)
  after
    File.rm(config.dataset_id)
  end

  defp save_last_processed_index({_value, index}, config) do
    if config.sourceType == "batch" do
      Persistence.record_last_processed_index(config.dataset_id, index)
    end
  end

  defp mark_duplicates(cache, {value, index}) do
    case Cache.mark_duplicates(cache, value) do
      {:ok, result} -> {:ok, {result, index}}
      result -> result
    end
  end

  defp mark_processed(config, message) do
    case config.sourceType do
      "stream" ->
        {:ok, message}

      "batch" ->
        process_batch(config, message)

      _ ->
        nil
    end
  end

  defp process_batch(reaper_config, {_value, index} = message) do
    last_processed_index = Persistence.get_last_processed_index(reaper_config.dataset_id)

    case index > last_processed_index do
      true ->
        {:ok, message}

      false ->
        {:index_processed, message}
    end
  end

  defp index_processed?({:index_processed, _message}), do: true
  defp index_processed?(_), do: false

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

  defp load({value, _index} = message, config, time_stamp) do
    case Loader.load(value, config, time_stamp) do
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
