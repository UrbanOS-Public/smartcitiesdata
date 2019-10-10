defmodule Forklift.DataWriter.Compaction do
  @moduledoc false

  require Logger
  alias SmartCity.Dataset
  alias Forklift.DataWriter.Compaction.Metric
  import Forklift

  @behaviour Pipeline.Writer
  @reader Application.get_env(:forklift, :data_reader)
  @writer Application.get_env(:forklift, :table_writer)

  @impl Pipeline.Writer
  @spec init(dataset: Dataset.t()) :: :ok | {:error, term()}
  def init(args) do
    config = parse_args(args)
    Logger.info("#{config.table} compaction started")

    reader_args(config.dataset)
    |> @reader.terminate()
  end

  @impl Pipeline.Writer
  @spec write({Time.t(), Time.t()}, dataset: Dataset.t()) :: :ok | {:error, term()}
  def write({start_time, end_time}, args) do
    config = parse_args(args)

    Time.diff(end_time, start_time, :millisecond)
    |> Metric.record(config.table)
  end

  @impl Pipeline.Writer
  @spec terminate(dataset: Dataset.t()) :: :ok | {:error, term()}
  def terminate(args) do
    config = parse_args(args)

    reader_args(config.dataset)
    |> @reader.init()
  end

  @impl Pipeline.Writer
  @spec compact(dataset: Dataset.t()) :: :ok | {:error, term()}
  def compact(args) do
    config = parse_args(args)

    case @writer.compact(table: config.table) do
      :ok ->
        Logger.info("#{config.table} compacted successfully")

      error ->
        Logger.error("#{config.table} failed to compact: #{inspect(error)}")
        {:error, error}
    end
  end

  defp parse_args(args) do
    dataset = Keyword.fetch!(args, :dataset)
    %{dataset: dataset, table: dataset.technical.systemName}
  end

  defp reader_args(dataset) do
    [
      instance: instance_name(),
      endpoints: Application.get_env(:forklift, :elsa_brokers),
      dataset: dataset,
      handler: Forklift.MessageHandler,
      input_topic_prefix: Application.get_env(:forklift, :input_topic_prefix),
      retry_count: Application.get_env(:forklift, :retry_count),
      retry_delay: Application.get_env(:forklift, :retry_initial_delay),
      topic_subscriber_config: Application.get_env(:forklift, :topic_subscriber_config, [])
    ]
  end
end
