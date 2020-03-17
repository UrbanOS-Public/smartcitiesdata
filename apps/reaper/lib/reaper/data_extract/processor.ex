defmodule Reaper.DataExtract.Processor do
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

  alias Reaper.DataExtract.{ValidationStage, SchemaStage, LoadStage}

  use Retry

  @min_demand 500
  @max_demand 1_000

  @doc """
  Downloads, decodes, and sends data to a topic
  """
  @spec process(SmartCity.Dataset.t()) :: Redix.Protocol.redis_value() | no_return()
  def process(%SmartCity.Dataset{} = unprovisioned_dataset) do
    Process.flag(:trap_exit, true)

    dataset =
      unprovisioned_dataset
      |> Providers.Helpers.Provisioner.provision()

    validate_destination(dataset)
    validate_cache(dataset)

    generated_time_stamp = DateTime.utc_now()

    {:ok, producer_stage} = create_producer_stage(dataset)
    {:ok, validation_stage} = ValidationStage.start_link(cache: dataset.id, dataset: dataset)
    {:ok, schema_stage} = SchemaStage.start_link(cache: dataset.id, dataset: dataset, start_time: generated_time_stamp)
    {:ok, load_stage} = LoadStage.start_link(cache: dataset.id, dataset: dataset, start_time: generated_time_stamp)

    GenStage.sync_subscribe(load_stage, to: schema_stage, min_demand: @min_demand, max_demand: @max_demand)
    GenStage.sync_subscribe(schema_stage, to: validation_stage, min_demand: @min_demand, max_demand: @max_demand)
    GenStage.sync_subscribe(validation_stage, to: producer_stage, min_demand: @min_demand, max_demand: @max_demand)

    wait_for_completion([producer_stage, validation_stage, schema_stage, load_stage])

    Persistence.remove_last_processed_index(dataset.id)
  rescue
    error ->
      Logger.error(Exception.format_stacktrace(__STACKTRACE__))
      Logger.error("Unable to continue processing dataset #{inspect(unprovisioned_dataset)} - Error #{inspect(error)}")

      reraise error, __STACKTRACE__
  after
    unprovisioned_dataset.id
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

  defp validate_cache(%SmartCity.Dataset{id: id, technical: %{allow_duplicates: false}}) do
    Horde.DynamicSupervisor.start_child(Reaper.Horde.Supervisor, {Reaper.Cache, name: id})
  end

  defp validate_cache(_dataset), do: nil

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
    retry with: exponential_backoff() |> randomize() |> cap(2_000) |> expiry(30_000), atoms: [false] do
      Elsa.create_topic(endpoints(), topic)
      Process.sleep(100)
      Elsa.topic?(endpoints(), topic)
    after
      true -> true
    else
      _ -> raise "Topic does not exist, everything is terrible!"
    end
  end

  defp start_topic_producer(topic) do
    {:ok, _pid} =
      Elsa.Supervisor.start_link(connection: :"#{topic}_producer", endpoints: endpoints(), producer: [topic: topic])

    retry with: constant_backoff(100) |> Stream.take(25) do
      :brod.get_producer(:"#{topic}_producer", topic, 0)
    after
      {:ok, _pid} -> true
    else
      _ -> raise "Cannot verify kafka producer for topic #{topic}"
    end
  end

  defp endpoints(), do: Application.get_env(:reaper, :elsa_brokers)

  defp topic_prefix(), do: Application.get_env(:reaper, :output_topic_prefix)
end
