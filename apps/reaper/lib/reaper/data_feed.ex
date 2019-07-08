defmodule Reaper.DataFeed do
  @moduledoc """
  This module processes a data source and sends its data to the output topic
  """
  require Logger

  alias Reaper.{
    Decoder,
    DataSlurper,
    UrlBuilder,
    Persistence,
    ReaperConfig,
    Persistence
  }

  alias Reaper.DataFeed.{ValidationStage, SchemaStage, LoadStage}

  @min_demand 500
  @max_demand 1_000

  @doc """
  Downloads, decodes, and sends data to a topic
  """
  @spec process(ReaperConfig.t(), atom()) :: Redix.Protocol.redis_value() | no_return()
  def process(%ReaperConfig{} = config, cache) do
    Process.flag(:trap_exit, true)

    generated_time_stamp = DateTime.utc_now()

    {:ok, producer_stage} =
      config
      |> UrlBuilder.build()
      |> DataSlurper.slurp(config.dataset_id, config.sourceHeaders, config.protocol)
      |> Decoder.decode(config)
      |> Stream.with_index()
      |> GenStage.from_enumerable()

    {:ok, validation_stage} = ValidationStage.start_link(cache: cache, config: config)
    {:ok, schema_stage} = SchemaStage.start_link(cache: cache, config: config, start_time: generated_time_stamp)
    {:ok, load_stage} = LoadStage.start_link(cache: cache, config: config, start_time: generated_time_stamp)

    GenStage.sync_subscribe(load_stage, to: schema_stage, min_demand: @min_demand, max_demand: @max_demand)
    GenStage.sync_subscribe(schema_stage, to: validation_stage, min_demand: @min_demand, max_demand: @max_demand)
    GenStage.sync_subscribe(validation_stage, to: producer_stage, min_demand: @min_demand, max_demand: @max_demand)

    wait_for_completion([producer_stage, validation_stage, schema_stage, load_stage])

    record_last_fetched_timestamp(config.dataset_id, generated_time_stamp)

    Persistence.remove_last_processed_index(config.dataset_id)
  rescue
    error ->
      Logger.error("Unable to continue processing dataset #{inspect(config)} - Error #{inspect(error)}")

      reraise error, __STACKTRACE__
  after
    config.dataset_id
    |> DataSlurper.determine_filename()
    |> File.rm()
  end

  defp wait_for_completion([]), do: true

  defp wait_for_completion(pids) do
    receive do
      {:EXIT, from, :normal} ->
        wait_for_completion(pids -- [from])

      {:EXIT, _from, reason} ->
        raise "Stage failed reason: #{inspect(reason)}"

      unknown ->
        Logger.warn("Unknown message received: #{inspect(unknown)}")
        wait_for_completion(pids)
    end
  end

  defp record_last_fetched_timestamp(dataset_id, timestamp) do
    Persistence.record_last_fetched_timestamp(dataset_id, timestamp)
  end
end
