defmodule Reaper.DataFeed do
  @moduledoc """
  This module processes a data source and sends its data to the output topic
  """
  require Logger

  alias Reaper.{
    Decoder,
    DataSlurper,
    UrlBuilder,
    Persistence
  }

  alias Reaper.DataFeed.{ValidationStage, SchemaStage, LoadStage}

  @min_demand 500
  @max_demand 1_000

  @doc """
  Downloads, decodes, and sends data to a topic
  """
  @spec process(SmartCity.Dataset.t(), atom()) :: Redix.Protocol.redis_value() | no_return()
  def process(%SmartCity.Dataset{} = dataset, cache) do
    Process.flag(:trap_exit, true)

    validate_destination(dataset)

    generated_time_stamp = DateTime.utc_now()

    {:ok, producer_stage} = create_producer_stage(dataset)
    {:ok, validation_stage} = ValidationStage.start_link(cache: cache, dataset: dataset)
    {:ok, schema_stage} = SchemaStage.start_link(cache: cache, dataset: dataset, start_time: generated_time_stamp)
    {:ok, load_stage} = LoadStage.start_link(cache: cache, dataset: dataset, start_time: generated_time_stamp)

    GenStage.sync_subscribe(load_stage, to: schema_stage, min_demand: @min_demand, max_demand: @max_demand)
    GenStage.sync_subscribe(schema_stage, to: validation_stage, min_demand: @min_demand, max_demand: @max_demand)
    GenStage.sync_subscribe(validation_stage, to: producer_stage, min_demand: @min_demand, max_demand: @max_demand)

    wait_for_completion([producer_stage, validation_stage, schema_stage, load_stage])

    Persistence.remove_last_processed_index(dataset.id)
  rescue
    error ->
      Logger.error("Unable to continue processing dataset #{inspect(dataset)} - Error #{inspect(error)}")

      reraise error, __STACKTRACE__
  after
    dataset.id
    |> DataSlurper.determine_filename()
    |> File.rm()
  end

  defp create_producer_stage(dataset) do
    dataset
    |> UrlBuilder.build()
    |> DataSlurper.slurp(dataset.id, dataset.technical.sourceHeaders, dataset.technical.protocol)
    |> Decoder.decode(dataset)
    |> Stream.with_index()
    |> GenStage.from_enumerable()
  end

  defp validate_destination(dataset) do
    topic = "#{topic_prefix()}-#{dataset.id}"
    create_topic(topic)
    start_topic_producer(topic)
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

  defp create_topic(topic) do
    :ok = Elsa.create_topic(endpoints(), topic)
  end

  defp start_topic_producer(topic) do
    {:ok, _pid} = Elsa.Producer.Supervisor.start_link(name: :"#{topic}_producer", endpoints: endpoints(), topic: topic)
  end

  defp endpoints(), do: Application.get_env(:reaper, :elsa_brokers)

  defp topic_prefix(), do: Application.get_env(:reaper, :output_topic_prefix)
end
