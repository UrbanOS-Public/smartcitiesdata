defmodule Reaper.DataExtract.LoadStage do
  @moduledoc false
  use GenStage
  use Properties, otp_app: :reaper

  require Logger

  alias SmartCity.Data
  alias Reaper.{Cache, Persistence}

  getter(:batch_size_in_bytes, generic: true, default: 900_000)
  getter(:output_topic_prefix, generic: true)
  getter(:profiling_enabled, generic: true)

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  def init(args) do
    state = %{
      ingestion: Keyword.fetch!(args, :ingestion),
      cache: Keyword.fetch!(args, :cache),
      batch: [],
      bytes: 0,
      originals: [],
      start_time: Keyword.fetch!(args, :start_time)
    }

    {:consumer, state}
  end

  def handle_events(events, _from, state) do
    new_state = Enum.reduce(events, state, &process_event/2)

    {:noreply, [], new_state}
  end

  def terminate(reason, state) do
    process_batch(state)
    reason
  end

  defp process_event({message, _index} = original, state) do
    {:ok, data_message} = convert_to_data_message(message, state)

    encoded_message = Jason.encode!(data_message)
    bytes = byte_size(encoded_message)

    case fit_in_batch?(state, bytes) do
      false ->
        process_batch(state)
        %{state | batch: [encoded_message], bytes: bytes, originals: [original]}

      true ->
        %{
          state
          | batch: [encoded_message | state.batch],
            bytes: bytes + state.bytes,
            originals: [original | state.originals]
        }
    end
  end

  defp fit_in_batch?(state, bytes) do
    state.bytes + bytes <= batch_size_in_bytes()
  end

  defp process_batch(%{batch: []}), do: nil

  defp process_batch(state) do
    send_to_kafka(state)
    mark_batch_processed(state)
    cache_batch(state)
  end

  defp send_to_kafka(%{ingestion: ingestion, batch: batch}) do
    topic = "#{output_topic_prefix()}-#{ingestion.id}"
    :ok = Elsa.produce(:"#{topic}_producer", topic, Enum.reverse(batch), partition: 0)
  end

  defp mark_batch_processed(%{ingestion: ingestion, originals: originals}) do
    {_message, max_index} =
      originals
      |> Enum.max_by(fn {_message, index} -> index end)

    Persistence.record_last_processed_index(ingestion.id, max_index)
  end

  defp cache_batch(%{cache: cache, originals: originals, ingestion: %{allow_duplicates: false}}) do
    Enum.each(originals, fn {message, _index} ->
      Cache.cache(cache, message)
    end)
  end

  defp cache_batch(_), do: nil

  defp convert_to_data_message(payload, state) do
    data = %{
      dataset_id: state.ingestion.targetDataset,
      operational: %{timing: add_timing(state)},
      payload: payload,
      _metadata: %{}
    }

    case Data.new(data) do
      {:error, reason} -> {:error, {:smart_city_data, reason}}
      result -> result
    end
  end

  defp add_timing(state) do
    case profiling_enabled() do
      true ->
        start = format_date(state.start_time)
        stop = format_date(DateTime.utc_now())
        [%{app: "reaper", label: "Ingested", start_time: start, end_time: stop}]

      _ ->
        []
    end
  end

  defp format_date(date) do
    DateTime.to_iso8601(date)
  end
end
