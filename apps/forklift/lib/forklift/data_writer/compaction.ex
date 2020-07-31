defmodule Forklift.DataWriter.Compaction do
  @moduledoc false

  require Logger
  alias SmartCity.Dataset
  alias Forklift.DataWriter.Compaction.Metric

  @behaviour Pipeline.Writer
  @writer Application.get_env(:forklift, :table_writer)

  @impl Pipeline.Writer
  @spec init(dataset: Dataset.t()) :: :ok | {:error, term()}
  def init(args) do
    config = parse_args(args)
    Logger.info("#{config.table} compaction started")

    Forklift.DataReaderHelper.terminate(config.dataset)
  end

  @impl Pipeline.Writer
  @spec write({Time.t(), Time.t()}, dataset: Dataset.t()) :: :ok | {:error, term()}
  def write({start_time, end_time}, args) do
    config = parse_args(args)

    Time.diff(end_time, start_time, :millisecond)
    add_event_count(config.table)
  end

  @impl Pipeline.Writer
  @spec terminate(dataset: Dataset.t()) :: :ok | {:error, term()}
  def terminate(args) do
    config = parse_args(args)

    Forklift.DataReaderHelper.init(config.dataset)
  end

  @impl Pipeline.Writer
  @spec compact(dataset: Dataset.t()) :: :ok | {:error, term()}
  def compact(args) do
    config = parse_args(args)

    try do
      case @writer.compact(table: config.table) do
        :ok ->
          Logger.info("#{config.table} compacted successfully")

        :skipped ->
          Logger.info("#{config.table} compaction skipped")
          :skipped

        error ->
          Logger.error("#{config.table} failed to compact: #{inspect(error)}")
          {:error, error}
      end
    rescue
      error ->
        Logger.error("#{config.table} failed to compact: #{inspect(error)}")
        {:error, error}
    end
  end

  defp parse_args(args) do
    dataset = Keyword.fetch!(args, :dataset)
    %{dataset: dataset, table: dataset.technical.systemName}
  end

  defp add_event_count(system_name) do
    [
      app: "forklift",
      system_name: system_name
    ]
    |> TelemetryEvent.add_event_count([:dataset_compaction_duration_total])
  rescue
    error ->
      Logger.error("Unable to update the metrics for #{system_name}: #{error}")
  end
end
