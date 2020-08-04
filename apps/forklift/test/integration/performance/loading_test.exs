defmodule Forklift.Performance.LoadingTest do
  use ExUnit.Case
  use Divo
  use Retry
  require Logger

  alias Forklift.TopicManager
  alias SmartCity.TestDataGenerator, as: TDG
  import Forklift
  import SmartCity.Event, only: [data_ingest_start: 0]
  import SmartCity.TestHelper

  @moduletag :performance

  @endpoints Application.get_env(:forklift, :elsa_brokers)
  @input_topic_prefix Application.get_env(:forklift, :input_topic_prefix)
  @output_topic Application.get_env(:forklift, :output_topic)

  defmodule SetupConfig do
    defstruct [
      :messages,
      processor_stages: 1,
      batch_stages: 1,
      batch_size: 1_000,
      batch_timeout: 2_000,
      prefetch_count: 0,
      prefetch_bytes: 0
    ]
  end

  setup_all do
    Logger.configure(level: :debug)
    Agent.start(fn -> 0 end, name: :counter)

    :ok
  end

  @tag timeout: :infinity
  test "run performance test" do
    # small_messages = generate_messages(10, 1_000)
    # medium_messages = generate_messages(10, 10_000)
    # big_messages = generate_messages(10, 100_000)
    huge_messages = generate_messages(10, 1_000_000)
    # wide_messages = generate_messages(100, 10_000)
    # stout_messages = generate_messages(500, 10_000)

    Benchee.run(
      %{
        "kafka" => fn {dataset, expected_count, input_topic, output_topic} = _output_from_before_each ->
          Brook.Event.send(instance_name(), data_ingest_start(), :author, dataset)

          eventually(
            fn ->
              current_total = get_total_messages(output_topic)

              assert current_total >= expected_count
            end,
            100,
            5000
          )

          {dataset, input_topic, output_topic}
        end
      },
      inputs: %{
        # "small" => %SetupConfig{messages: small_messages}
        # "medium_1_batch" => %SetupConfig{messages: medium_messages, batch_stages: 1},
        # "medium_2_batch" => %SetupConfig{messages: medium_messages, batch_stages: 2},
        # "medium_4_batch" => %SetupConfig{messages: medium_messages, batch_stages: 4},
        # "medium_8_proc_8_batch" => %SetupConfig{messages: medium_messages, processor_stages: 8, batch_stages: 8},
        # "medium_16_batch" => %SetupConfig{messages: medium_messages, batch_stages: 16},
        # "medium_1_proc" => %SetupConfig{messages: medium_messages, processor_stages: 1},
        # "medium_2_proc" => %SetupConfig{messages: medium_messages, processor_stages: 2},
        # "medium_4_proc" => %SetupConfig{messages: medium_messages, processor_stages: 4},
        # "medium_8_proc" => %SetupConfig{messages: medium_messages, processor_stages: 8},
        # "medium_16_proc" => %SetupConfig{messages: medium_messages, processor_stages: 16},
        # "big_pref_b1M" => %SetupConfig{messages: big_messages, processor_stages: 8, prefetch_bytes: 1_000_000},
        # "big_pref_b10M" => %SetupConfig{messages: big_messages, processor_stages: 8, prefetch_bytes: 10_000_000},
        # "big_pref_b100M" => %SetupConfig{messages: big_messages, processor_stages: 8, prefetch_bytes: 100_000_000},
        "huge_pref_b5M" => %SetupConfig{messages: huge_messages}
        # "huge_pref_b10M" => %SetupConfig{messages: huge_messages, processor_stages: 8, prefetch_bytes: 10_000_000},
        # "huge_pref_b100M" => %SetupConfig{messages: huge_messages, processor_stages: 8, prefetch_bytes: 100_000_000},
        # "medium_pref_m10000" => %SetupConfig{messages: medium_messages, processor_stages: 8, prefetch_count: 10_000},
        # "small_pref_b10M" => %SetupConfig{messages: small_messages, processor_stages: 8, prefetch_bytes: 10_000_000},
        # "small_pref_m10000" => %SetupConfig{messages: small_messages, processor_stages: 8, prefetch_count: 10_000},
        # "big" => %SetupConfig{messages: big_messages},
        # "big_8_proc" => %SetupConfig{messages: big_messages, processor_stages: 8},
        # "wide" => %SetupConfig{messages: wide_messages},
        # "wide_8_proc" => %SetupConfig{messages: wide_messages, processor_stages: 8},
        # "stout" => %SetupConfig{messages: stout_messages},
        # "stout_8_proc" => %SetupConfig{messages: stout_messages, processor_stages: 8}
      },
      before_scenario: fn %SetupConfig{
                            messages: messages,
                            prefetch_count: prefetch_count,
                            prefetch_bytes: prefetch_bytes
                          } = _parameters_from_inputs ->
        existing_topic_config = Application.get_env(:forklift, :topic_subscriber_config)

        updated_topic_config =
          Keyword.merge(
            existing_topic_config,
            prefetch_count: prefetch_count,
            prefetch_bytes: prefetch_bytes
          )

        Application.put_env(:forklift, :topic_subscriber_config, updated_topic_config)

        messages
      end,
      before_each: fn {messages, width, count} = _output_from_before_scenario ->
        dataset = create_dataset(num_fields: width)

        iteration = Agent.get_and_update(:counter, fn s -> {s, s + 1} end)
        Logger.debug("Iteration #{iteration} for dataset #{dataset.id} with #{count} messages at width #{width}")

        create_table(dataset)
        {input_topic, output_topic} = setup_topics(dataset)
        load_messages(dataset, input_topic, messages, count, 10_000)

        {dataset, count, input_topic, output_topic}
      end,
      after_each: fn {dataset, input_topic, output_topic} = _output_from_run ->
        Forklift.DataReaderHelper.terminate(dataset)

        Elsa.delete_topic(@endpoints, input_topic)
        Elsa.delete_topic(@endpoints, output_topic)
      end,
      time: 30,
      memory_time: 0.5,
      warmup: 0
    )
  end

  defp generate_messages(width, count) do
    temporary_dataset = create_dataset(num_fields: width)

    messages =
      1..count
      |> Enum.map(fn _ -> create_data_message(temporary_dataset) end)

    {messages, width, count}
  end

  defp setup_topics(dataset) do
    input_topic = "#{@input_topic_prefix}-#{dataset.id}"
    output_topic = @output_topic

    Elsa.create_topic(@endpoints, input_topic)
    Elsa.create_topic(@endpoints, output_topic)
    wait_for_topic!(input_topic)
    wait_for_topic!(output_topic)

    {input_topic, output_topic}
  end

  defp load_messages(dataset, topic, messages, expected_count, producer_chunk_size) do
    num_producers = div(expected_count, producer_chunk_size)
    producer_name = :"#{topic}_producer"

    Logger.debug("Loading #{expected_count} messages into kafka with #{num_producers} producers")

    {:ok, producer_pid} =
      Elsa.Supervisor.start_link(endpoints: @endpoints, producer: [topic: topic], connection: producer_name)

    Elsa.Producer.ready?(producer_name)

    messages
    |> Stream.map(&prepare_messages(&1, dataset))
    |> Stream.chunk_every(producer_chunk_size)
    |> Enum.map(&spawn_producer_chunk(&1, topic, producer_name))
    |> Enum.each(&Task.await(&1, :infinity))

    eventually(
      fn ->
        current_total = get_total_messages(topic, 1)

        assert current_total >= expected_count
      end,
      200,
      5000
    )

    Process.exit(producer_pid, :normal)

    Logger.debug("Done loading #{expected_count} messages")
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

  defp get_total_messages(topic, num_partitions \\ 1) do
    0..(num_partitions - 1)
    |> Enum.map(fn partition -> :brod.resolve_offset(@endpoints, topic, partition) end)
    |> Enum.map(fn {:ok, value} -> value end)
    |> Enum.sum()
  end

  defp create_dataset(opts) do
    num_fields = Keyword.get(opts, :num_fields)
    schema = Enum.map(1..num_fields, fn i -> %{name: "name-#{i}", type: "string"} end)

    dataset = TDG.create_dataset(technical: %{schema: schema})
    dataset
  end

  defp create_table(dataset) do
    num_fields = Enum.count(dataset.technical.schema)

    fields =
      1..num_fields
      |> Enum.map(fn i -> ~s|"name-#{i}" varchar| end)
      |> Enum.join(", ")

    prestige_opts()
    |> Prestige.new_session()
    |> Prestige.execute("create table #{dataset.technical.systemName} (#{fields})")
  end

  defp create_data_message(dataset) do
    schema = dataset.technical.schema

    payload =
      Enum.reduce(schema, %{}, fn field, acc ->
        Map.put(acc, field.name, "some value")
      end)

    data = TDG.create_data(dataset_id: dataset.id, payload: payload)
    {"", data}
  end

  def prestige_opts() do
    Application.get_env(:prestige, :session_opts)
  end

  defp wait_for_topic!(topic) do
    wait exponential_backoff(100) |> Stream.take(10) do
      Elsa.topic?(@endpoints, topic)
    after
      _ -> topic
    else
      _ -> raise "Timed out waiting for #{topic} to be available"
    end
  end
end
