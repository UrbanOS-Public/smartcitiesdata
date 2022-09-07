defmodule Forklift.DataWriter do
  @moduledoc """
  Implementation of `Pipeline.Writer` for Forklift's edges.
  """

  @behaviour Pipeline.Writer

  use Retry
  use Properties, otp_app: :forklift

  alias SmartCity.Data
  alias Forklift.IngestionProgress
  alias Forklift.Jobs.DataMigration

  require Logger
  import SmartCity.Data, only: [end_of_data: 0]
  import SmartCity.Event, only: [data_ingest_end: 0]

  @instance_name Forklift.instance_name()

  getter(:topic_writer, generic: true)
  getter(:table_writer, generic: true)
  getter(:retry_max_wait, generic: true)
  getter(:retry_count, generic: true)
  getter(:elsa_brokers, generic: true)
  getter(:input_topic_prefix, generic: true)
  getter(:output_topic, generic: true)
  getter(:max_outgoing_bytes, generic: true, default: 900_000)
  getter(:producer_name, generic: true)
  getter(:profiling_enabled, generic: true)
  getter(:retry_initial_delay, generic: true)
  getter(:s3_writer_bucket, generic: true)

  @impl Pipeline.Writer
  @doc """
  Ensures a table exists using `:table_writer` from Forklift's application environment.
  """
  def init(table: table, schema: dataset_schema, json_partitions: json_partitions, main_partitions: main_partitions) do
    schema_with_ingestion_metadata = dataset_schema |> add_ingestion_metadata_to_schema()

    table_writer().init(
      table: table,
      schema: schema_with_ingestion_metadata,
      json_partitions: json_partitions,
      main_partitions: main_partitions
    )
  end

  @impl Pipeline.Writer
  @doc """
  Writes data to PrestoDB and Kafka using `:table_writer` and `:topic_writer` from
  Forklift's application environment.

  Timing information is recorded for writing to the table and included in the data
  written to Kafka.

  If an end-of-data message is received, a `data:ingest:end` event is sent.
  """
  def write(data, opts) do
    dataset = Keyword.fetch!(opts, :dataset)
    ingestion_id = Keyword.fetch!(opts, :ingestion_id)
    extraction_start_time = Keyword.fetch!(opts, :extraction_start_time)

    case ingest_status(data) do
      {:ok, batch_data} ->
        Enum.reverse(batch_data)
        |> do_write(dataset, ingestion_id, extraction_start_time)

      {:final, batch_data} ->
        results =
          Enum.reverse(batch_data)
          |> do_write(dataset, ingestion_id, extraction_start_time)

        Brook.Event.send(@instance_name, data_ingest_end(), :forklift, dataset)

        results
    end
  end

  @impl Pipeline.Writer
  def delete(dataset) do
    topic = "#{input_topic_prefix()}-#{dataset.id}"

    [endpoints: elsa_brokers(), topic: topic]
    |> topic_writer().delete()

    [dataset: dataset]
    |> table_writer().delete()
  end

  @spec bootstrap() :: :ok | {:error, term()}
  @doc """
  Initializes `:topic_writer` from Forklift's application environment if an
  output_topic is configured. Includes creating the topic if necessary.
  """
  def bootstrap do
    case output_topic() do
      nil ->
        :ok

      topic ->
        bootstrap_args(topic)
        |> topic_writer().init()
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

  defp do_write(data, dataset, ingestion_id, extraction_start_time) do
    started_data = Enum.map(data, &add_start_time/1)
    ingestion_info_data = Enum.map(started_data, &add_ingestion_info/1)

    retry with: exponential_backoff(100) |> cap(retry_max_wait()) |> Stream.take(retry_count()) do
      write_to_table(ingestion_info_data, dataset, ingestion_id, extraction_start_time)
    after
      {:ok, write_timing} -> add_total_time(data, ingestion_info_data, write_timing)
    else
      {:error, reason} ->
        raise RuntimeError, inspect(reason)
    end
  end

  defp write_to_table(data, %{technical: technical} = dataset, ingestion_id, extraction_start_time) do
    with write_start <- Data.Timing.current_time(),
         :ok <-
           table_writer().write(data,
             table: technical.systemName,
             schema: add_ingestion_metadata_to_schema(technical.schema),
             bucket: s3_writer_bucket(),
             partition_values: [_extraction_start_time: extraction_start_time, _ingestion_id: ingestion_id],
             json_partitions: ["_extraction_start_time", "_ingestion_id"],
             main_partitions: ["_ingestion_id"]
           ),
         write_end <- Data.Timing.current_time(),
         write_timing <-
           Data.Timing.new(@instance_name, "presto_insert_time", write_start, write_end) do
      ingestion_status = IngestionProgress.new_messages(ingestion_id, extraction_start_time, Enum.count(data))

      if ingestion_status == :ingestion_complete do
        DataMigration.compact(dataset, ingestion_id, extraction_start_time)
      end

      {:ok, write_timing}
    end
  end

  def add_ingestion_metadata_to_schema(schema) do
    ingestion_metadata_schema = [
      %{name: "_extraction_start_time", type: "long"},
      %{name: "_ingestion_id", type: "string"}
    ]

    schema ++ ingestion_metadata_schema
  end

  def write_to_topic(data) do
    writer_args = [instance: @instance_name, producer_name: producer_name()]

    data
    |> Enum.map(fn datum ->
      {datum._metadata.kafka_key, Forklift.Util.remove_from_metadata(datum, :kafka_key)}
    end)
    |> Enum.map(fn {key, datum} -> {key, Jason.encode!(datum)} end)
    |> Forklift.Util.chunk_by_byte_size(max_outgoing_bytes(), fn {key, value} ->
      byte_size(key) + byte_size(value)
    end)
    |> Enum.each(fn msg_chunk -> topic_writer().write(msg_chunk, writer_args) end)
  end

  defp add_start_time(datum) do
    datum |> Forklift.Util.add_to_metadata(:forklift_start_time, Data.Timing.current_time())
  end

  defp add_ingestion_info(data) do
    payload = Map.get(data, :payload, %{})

    ingestion_info_payload =
      Map.merge(payload, %{
        "_extraction_start_time" => data.extraction_start_time,
        "_ingestion_id" => data.ingestion_id
      })

    data |> Map.merge(%{payload: ingestion_info_payload})
  end

  defp add_total_time(data, started_data, write_timing) do
    case profiling_enabled() do
      true ->
        Enum.map(started_data, &Data.add_timing(&1, write_timing))
        |> Enum.map(&add_timing/1)

      _ ->
        data
    end
  end

  defp add_timing(datum) do
    start_time = datum._metadata.forklift_start_time
    timing = Data.Timing.new("forklift", "total_time", start_time, Data.Timing.current_time())

    Data.add_timing(datum, timing)
    |> Forklift.Util.remove_from_metadata(:forklift_start_time)
  end

  defp bootstrap_args(topic) do
    [
      instance: @instance_name,
      endpoints: elsa_brokers(),
      topic: topic,
      producer_name: producer_name(),
      retry_count: retry_count(),
      retry_delay: retry_initial_delay()
    ]
  end
end
