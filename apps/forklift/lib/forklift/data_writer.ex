defmodule Forklift.DataWriter do
  @moduledoc "TODO"
  @behaviour Pipeline.Writer

  use Retry
  alias SmartCity.Data
  alias Forklift.DataWriter.Metric

  require Logger
  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_ingest_end: 0]

  @topic_writer Application.get_env(:forklift, :topic_writer)
  @table_writer Application.get_env(:forklift, :table_writer)
  @max_wait_time 1_000 * 60 * 60

  @impl Pipeline.Writer
  def init(args) do
    @table_writer.init(args)
  end

  @impl Pipeline.Writer
  def write(data, opts) do
    dataset = Keyword.fetch!(opts, :dataset)

    case ingest_status(data) do
      {:ok, batch_data} ->
        :ok =
          Enum.reverse(batch_data)
          |> do_write(dataset)

      {:final, batch_data} ->
        :ok =
          Enum.reverse(batch_data)
          |> do_write(dataset)

        Brook.Event.send(:forklift, data_ingest_end(), :forklift, dataset)
    end
  end

  defp ingest_status(data) do
    Enum.reduce_while(data, {:_, []}, &handle_eod/2)
  end

  defp handle_eod(end_of_data(), {_, acc}) do
    {:halt, {:final, acc}}
  end

  defp handle_eod(message, {_, acc}) do
    {:cont, {:ok, [message | acc]}}
  end

  defp do_write(data, dataset) do
    started_data = Enum.map(data, &add_start_time/1)

    retry with: exponential_backoff(100) |> cap(@max_wait_time) do
      write_to_table(started_data, dataset)
    after
      {:ok, write_timing} ->
        Enum.map(started_data, &Data.add_timing(&1, write_timing))
        |> Enum.map(&add_total_time/1)
        |> write_to_topic()
    else
      {:error, reason} -> raise reason
    end
  end

  @spec one_time_init() :: :ok | {:error, term()}
  def one_time_init do
    case Application.get_env(:forklift, :output_topic) do
      nil ->
        :ok

      topic ->
        one_time_init_args(:forklift, topic)
        |> @topic_writer.init()
    end
  end

  @spec compact_datasets() :: :ok
  def compact_datasets do
    Logger.info("Beginning dataset compaction")

    Forklift.Datasets.get_all!()
    |> Enum.each(fn dataset ->
      table = dataset.technical.systemName
      start_time = Time.utc_now()

      case @table_writer.compact(table: table) do
        :ok -> Logger.info("#{table} compacted successfully")
        error -> Logger.error("#{table} failed to compact: #{inspect(error)}")
      end

      Time.utc_now()
      |> Time.diff(start_time, :millisecond)
      |> Metric.record(table)
    end)

    Logger.info("Completed dataset compaction")
  end

  defp write_to_table(data, %{technical: metadata}) do
    with write_start <- Data.Timing.current_time(),
         :ok <- @table_writer.write(data, table: metadata.systemName, schema: metadata.schema),
         write_end <- Data.Timing.current_time(),
         write_timing <- Data.Timing.new(:forklift, "presto_insert_time", write_start, write_end) do
      {:ok, write_timing}
    end
  end

  defp write_to_topic(data) do
    max_bytes = Application.get_env(:forklift, :max_outgoing_bytes, 900_000)
    writer_args = [instance: :forklift, producer_name: Application.get_env(:forklift, :producer_name)]

    data
    |> Enum.map(fn datum -> {datum._metadata.kafka_key, Forklift.Util.remove_from_metadata(datum, :kafka_key)} end)
    |> Enum.map(fn {key, datum} -> {key, Jason.encode!(datum)} end)
    |> Forklift.Util.chunk_by_byte_size(max_bytes, fn {key, value} -> byte_size(key) + byte_size(value) end)
    |> Enum.each(fn msg_chunk -> @topic_writer.write(msg_chunk, writer_args) end)
  end

  defp add_start_time(datum) do
    Forklift.Util.add_to_metadata(datum, :forklift_start_time, Data.Timing.current_time())
  end

  defp add_total_time(datum) do
    start_time = datum._metadata.forklift_start_time
    timing = Data.Timing.new("forklift", "total_time", start_time, Data.Timing.current_time())

    Data.add_timing(datum, timing)
    |> Forklift.Util.remove_from_metadata(:forklift_start_time)
  end

  def one_time_init_args(instance, topic) do
    [
      instance: instance,
      endpoints: Application.get_env(instance, :elsa_brokers),
      topic: topic,
      producer_name: Application.get_env(instance, :producer_name),
      retry_count: Application.get_env(instance, :retry_count),
      retry_delay: Application.get_env(instance, :retry_initial_delay)
    ]
  end
end
