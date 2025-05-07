defmodule Performance.Kafka do
  @moduledoc """
  Utilities for working with kafka in performance tests
  """

  use Retry
  import SmartCity.TestHelper, only: [eventually: 3]

  alias Performance.SetupConfig
  require Logger

  def tune_consumer_parameters(otp_app, %SetupConfig{} = params) do
    {_messages, kafka_parameters} = Map.split(params, [:messages])

    existing_topic_config = Application.get_env(otp_app, :topic_subscriber_config, Keyword.new())

    updated_topic_config =
      Keyword.merge(
        existing_topic_config,
        Keyword.new(Map.from_struct(kafka_parameters))
      )

    Application.put_env(otp_app, :topic_subscriber_config, updated_topic_config)
    Logger.info("Tuned kafka config:")

    Application.get_env(otp_app, :topic_subscriber_config)
    |> inspect()
    |> Logger.info()
  end

  def get_message_count(endpoints, topic, num_partitions) do
    0..(num_partitions - 1)
    |> Enum.map(fn partition -> :brod.resolve_offset(endpoints, topic, partition) end)
    |> Enum.map(fn {:ok, value} -> value end)
    |> Enum.sum()
  end

  def load_messages(endpoints, dataset, topic, messages, expected_count, producer_chunk_size) do
    num_producers = max(div(expected_count, producer_chunk_size), 1)
    producer_name = :"#{topic}_producer"

    Logger.info(
      "Loading #{expected_count} messages into kafka with #{num_producers} producers for topic #{topic}"
    )

    {:ok, producer_pid} =
      Elsa.Supervisor.start_link(
        endpoints: endpoints,
        producer: [topic: topic],
        connection: producer_name
      )

    Elsa.Producer.ready?(producer_name)

    messages
    |> Stream.map(&prepare_messages(&1, dataset))
    |> Stream.chunk_every(producer_chunk_size)
    |> Enum.map(&spawn_producer_chunk(&1, topic, producer_name))
    |> Enum.each(&Task.await(&1, :infinity))

    eventually(
      fn ->
        current_total = get_total_messages(endpoints, topic, 1)

        current_total >= expected_count
      end,
      200,
      5000
    )

    Process.exit(producer_pid, :normal)

    Logger.info("Done loading #{expected_count} messages into #{topic}")
  end

  def get_total_messages(endpoints, topic, num_partitions \\ 1) do
    0..(num_partitions - 1)
    |> Enum.map(fn partition -> :brod.resolve_offset(endpoints, topic, partition) end)
    |> Enum.map(fn {:ok, value} -> value end)
    |> Enum.sum()
  end

  def wait_for_topic!(endpoints, topic) do
    wait exponential_backoff(100) |> Stream.take(10) do
      Elsa.topic?(endpoints, topic)
    after
      _ -> topic
    else
      _ -> raise "Timed out waiting for #{topic} to be available"
    end
  end

  def generate_consumer_scenarios(message_combos) do
    low_max_bytes = {"lmb", 1_000_000}
    mid_max_bytes = {"mmb", 10_000_000}
    high_max_bytes = {"hmb", 100_000_000}

    low_max_wait_time = {"lmw", 1_000}
    mid_max_wait_time = {"mmw", 10_000}
    high_max_wait_time = {"hmw", 60_000}

    low_min_bytes = {"lmib", 0}
    mid_min_bytes = {"mmib", 5_000}
    high_min_bytes = {"hmib", 1_000_000}

    low_prefetch_count = {"lpc", 0}
    mid_prefetch_count = {"mpc", 100_000}
    high_prefetch_count = {"hpc", 1_000_000}

    low_prefetch_bytes = {"lpb", 1_000_000}
    mid_prefetch_bytes = {"mpb", 10_000_000}
    high_prefetch_bytes = {"hpb", 100_000_000}

    combos =
      Combinatorics.product([
        message_combos,
        [low_max_bytes, mid_max_bytes, high_max_bytes],
        [low_max_wait_time, mid_max_wait_time, high_max_wait_time],
        [low_min_bytes, mid_min_bytes, high_min_bytes],
        [low_prefetch_count, mid_prefetch_count, high_prefetch_count],
        [low_prefetch_bytes, mid_prefetch_bytes, high_prefetch_bytes]
      ])

    Enum.map(combos, fn l ->
      {names, values} = Enum.unzip(l)

      label = Enum.join(names, ".")

      options =
        Enum.zip(
          [:messages, :max_bytes, :max_wait_time, :min_bytes, :prefetch_count, :prefetch_bytes],
          values
        )
        |> Keyword.new()

      {label, struct(SetupConfig, options)}
    end)
    |> Map.new()
  end

  def setup_topics(names, endpoints) do
    Enum.map(names, fn name ->
      Elsa.create_topic(endpoints, name)
      wait_for_topic!(endpoints, name)
    end)
    |> List.to_tuple()
  end

  def setup_topics(prefixes, dataset, endpoints) do
    Enum.map(prefixes, fn prefix ->
      topic = "#{prefix}-#{dataset.id}"
      Logger.info("Setting up #{topic} for #{dataset.id}")
      topic
    end)
    |> setup_topics(endpoints)
  end

  def delete_topics(names, endpoints) do
    Enum.map(names, fn name ->
      Elsa.delete_topic(endpoints, name)
    end)
    |> List.to_tuple()
  end

  def delete_topics(prefixes, dataset, endpoints) do
    Enum.map(prefixes, fn prefix ->
      topic = "#{prefix}-#{dataset.id}"
      Logger.info("Deleting topic #{topic} for #{dataset.id}")
      topic
    end)
    |> delete_topics(endpoints)
  end

  defp prepare_messages({key, message}, dataset) do
    json =
      message
      |> Map.put(:dataset_id, dataset.id)
      |> Jason.encode!()

    {key, json}
  end

  defp spawn_producer_chunk(chunk, topic, producer_name) do
    Task.async(fn ->
      chunk
      |> Stream.chunk_every(1000)
      |> Enum.each(fn load_chunk ->
        Elsa.produce(producer_name, topic, load_chunk, partition: 0)
      end)
    end)
  end
end
