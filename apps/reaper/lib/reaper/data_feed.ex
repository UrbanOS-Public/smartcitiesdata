defmodule Reaper.DataFeed do
  @moduledoc """
  An ETL process configured by `Reaper.ConfigServer` and supervised by `Reaper.FeedSupervisor`.

  Extracts data from a given HTTP endpoint.
  Transforms with a given module's `&transform/1` function.
  Loads onto the "raw" Kafka topic.
  """

  use GenServer
  alias Reaper.{Cache, Decoder, Extractor, Loader, UrlBuilder, Util, Recorder}

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

  def init(%{pids: %{name: name}, dataset: dataset} = args) do
    schedule_work(dataset.operational.cadence)

    Horde.Registry.register(Reaper.Registry, name)
    {:ok, args}
  end

  def handle_info(:work, %{pids: %{cache: cache}, dataset: dataset} = state) do
    generated_time_stamp = DateTime.utc_now()

    dataset
    |> UrlBuilder.build()
    |> Extractor.extract()
    |> Decoder.decode(dataset.operational.sourceFormat)
    |> Cache.dedupe(cache)
    |> Loader.load(dataset.id)
    |> Cache.cache(cache)
    |> Recorder.record_last_fetched_timestamp(dataset.id, generated_time_stamp)

    timer_ref = schedule_work(dataset.operational.cadence)

    {:noreply, Util.deep_merge(state, %{timer_ref: timer_ref})}
  end

  defp schedule_work(cadence) do
    Process.send_after(self(), :work, cadence)
  end

  def handle_cast({:update, config}, state) do
    {:noreply, Util.deep_merge(state, config)}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end
end
