defmodule Reaper.DataFeedServer do
  @moduledoc """
  An ETL process configured by `Reaper.ConfigServer` and supervised by `Reaper.FeedSupervisor`.

  Extracts data from a given HTTP endpoint.
  Transforms with a given module's `&transform/1` function.
  Loads onto the "raw" Kafka topic.
  """

  use GenServer
  alias Reaper.{Cache, Decoder, Extractor, Loader, UrlBuilder, Util, Persistence, ReaperConfig}

  ## CLIENT

  def update(data_feed, state) do
    GenServer.cast(data_feed, {:update, state})
  end

  def get(data_feed) do
    GenServer.call(data_feed, :get)
  end

  ## SERVER

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(%{pids: %{name: name}, reaper_config: reaper_config} = args) do
    reaper_config
    |> calculate_next_run_time()
    |> schedule_work()

    Horde.Registry.register(Reaper.Registry, name)

    {:ok, args}
  end

  def handle_info(:work, %{pids: %{cache: cache}, reaper_config: reaper_config} = state) do
    generated_time_stamp = DateTime.utc_now()

    reaper_config
    |> UrlBuilder.build()
    |> Extractor.extract(reaper_config.sourceFormat)
    |> Decoder.decode(reaper_config)
    |> Cache.dedupe(cache)
    |> Loader.load(reaper_config, generated_time_stamp)
    |> Cache.cache(cache)
    |> record_last_fetched_timestamp(reaper_config.dataset_id, generated_time_stamp)

    timer_ref = schedule_work(reaper_config.cadence)

    case reaper_config.cadence do
      "once" ->
        {:stop, {:shutdown, "transient process finished its work"}, state}

      _ ->
        {:noreply, Util.deep_merge(state, %{timer_ref: timer_ref})}
    end
  end

  defp schedule_work(nil), do: nil
  defp schedule_work("once"), do: nil

  defp schedule_work(cadence) do
    Process.send_after(self(), :work, cadence)
  end

  def handle_cast({:update, config}, state) do
    {:noreply, Map.put(state, :reaper_config, config)}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  def calculate_next_run_time(%ReaperConfig{dataset_id: id, cadence: "once"}) do
    case Persistence.get_last_fetched_timestamp(id) do
      nil -> 0
      _last -> nil
    end
  end

  def calculate_next_run_time(reaper_config) do
    last_run_time =
      case Persistence.get_last_fetched_timestamp(reaper_config.dataset_id) do
        nil -> DateTime.from_unix!(0)
        exists -> exists
      end

    expected_run_time = DateTime.add(last_run_time, reaper_config.cadence, :millisecond)
    remaining_wait_time = DateTime.diff(expected_run_time, DateTime.utc_now(), :millisecond)

    max(0, remaining_wait_time)
  end

  defp record_last_fetched_timestamp([], dataset_id, timestamp),
    do: Persistence.record_last_fetched_timestamp(dataset_id, timestamp)

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
