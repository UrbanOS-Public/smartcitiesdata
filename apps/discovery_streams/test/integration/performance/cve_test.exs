defmodule DiscoveryStreams.Performance.CveTest do
  use ExUnit.Case
  use Divo
  use Retry
  require Logger

  use DiscoveryStreamsWeb.ChannelCase
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [data_ingest_start: 0]
  import SmartCity.TestHelper

  @moduletag :performance

  @endpoints Application.get_env(:discovery_streams, :endpoints)
  @input_topic_prefix "transformed"

  @messages %{
    map: File.read!(File.cwd!() <> "/test/integration/performance/map_message.json") |> Jason.decode!(),
    spat: File.read!(File.cwd!() <> "/test/integration/performance/spat_message.json") |> Jason.decode!(),
    bsm: File.read!(File.cwd!() <> "/test/integration/performance/bsm_message.json") |> Jason.decode!()
  }

  defmodule SetupConfig do
    defstruct [
      :messages,
      prefetch_count: 0,
      prefetch_bytes: 1_000_000,
      max_bytes: 1_000_000,
      max_wait_time: 10_000,
      min_bytes: 0
    ]
  end

  setup_all do
    Logger.configure(level: :warn)
    Agent.start(fn -> 0 end, name: :counter)

    :ok
  end

  @tag timeout: :infinity
  test "run performance test" do
    map_messages = generate_messages(1_000, :map)
    spat_messages = generate_messages(1_000, :spat)
    bsm_messages = generate_messages(1_000, :bsm)

    low_max_bytes = {"l", 1_000_000}
    mid_max_bytes = {"m", 10_000_000}
    high_max_bytes = {"h", 100_000_000}

    low_max_wait_time = {"l", 1_000}
    mid_max_wait_time = {"m", 10_000}
    high_max_wait_time = {"h", 60_000}

    low_min_bytes = {"l", 0}
    mid_min_bytes = {"m", 1_000}
    high_min_bytes = {"h", 1_000_000}

    low_prefetch_count = {"l", 0}
    mid_prefetch_count = {"m", 100_000}
    high_prefetch_count = {"h", 1_000_000}

    low_prefetch_bytes = {"l", 1_000_000}
    mid_prefetch_bytes = {"m", 10_000_000}
    high_prefetch_bytes = {"h", 100_000_000}

    combos =
      Combinatorics.product([
        [{"spat", spat_messages}, {"bsm", bsm_messages}],
        [low_max_bytes],
        [low_max_wait_time],
        [low_min_bytes],
        [low_prefetch_count],
        [low_prefetch_bytes]
      ])

    scenarios =
      Enum.map(combos, fn l ->
        {names, values} = Enum.unzip(l)

        label = Enum.join(names, ".")

        options =
          Enum.zip([:messages, :max_bytes, :max_wait_time, :min_bytes, :prefetch_count, :prefetch_bytes], values)
          |> Keyword.new()

        {label, struct(SetupConfig, options)}
      end)
      |> Map.new()

    Benchee.run(
      %{
        "kafka" => fn {dataset, expected_count, input_topic} = _output_from_before_each ->
          current_total = get_message_count(dataset.technical.systemName, 1_000)
          IO.inspect("output is #{current_total} of #{expected_count}")

          # assert current_total >= expected_count

          {dataset, input_topic}
        end
      },
      inputs: scenarios,
      before_scenario: fn %SetupConfig{
                            messages: messages,
                            prefetch_count: prefetch_count,
                            prefetch_bytes: prefetch_bytes,
                            min_bytes: min_bytes,
                            max_bytes: max_bytes,
                            max_wait_time: max_wait_time
                          } = _parameters_from_inputs ->
        # existing_topic_config = Application.get_env(:discovery_streams, :topic_subscriber_config)

        # updated_topic_config =
        #   Keyword.merge(
        #     existing_topic_config,
        #     prefetch_count: prefetch_count,
        #     prefetch_bytes: prefetch_bytes,
        #     min_bytes: min_bytes,
        #     max_bytes: max_bytes,
        #     max_wait_time: max_wait_time
        #   )

        # Application.put_env(:discovery_streams, :topic_subscriber_config, updated_topic_config)

        # Application.get_env(:discovery_streams, :topic_subscriber_config, updated_topic_config)
        # |> inspect(label: "topic setup for scenario")
        # |> Logger.warn()

        messages
      end,
      before_each: fn {messages, count} = _output_from_before_scenario ->
        dataset = create_cve_dataset()

        iteration = Agent.get_and_update(:counter, fn s -> {s, s + 1} end)
        Logger.debug("Iteration #{iteration} for dataset #{dataset.id}")

        {input_topic} = setup_topics(dataset)

        Brook.Event.send(:discovery_streams, data_ingest_start(), :author, dataset)
        eventually(fn ->
          assert {:ok, _, socket} =
            DiscoveryStreamsWeb.UserSocket
            |> socket()
            |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset.technical.systemName}")
        end,
          100,
          5000
        )

        {:ok, _, _socket} = DiscoveryStreamsWeb.UserSocket
        |> socket()
        |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset.technical.systemName}")
        |> IO.inspect(label: "welcome to hell")

        # Process.sleep(30_000)

        load_messages(dataset, input_topic, messages, count, 10_000)

        {dataset, count, input_topic}
      end,
      after_each: fn {dataset, input_topic} = _output_from_run ->
        DiscoveryStreams.Stream.Supervisor.terminate_child(dataset.id)

        Elsa.delete_topic(@endpoints, input_topic)
      end,
      time: 30,
      memory_time: 1,
      warmup: 0
    )
  end

  defp generate_messages(count, type) do
    temporary_dataset = create_cve_dataset()

    messages =
      1..count
      |> Enum.map(fn _ -> create_data_message(temporary_dataset, type) end)

    Logger.debug("Generated #{length(messages)} #{inspect(type)} messages")
    {messages, count}
  end

  defp setup_topics(dataset) do
    input_topic = "#{@input_topic_prefix}-#{dataset.id}"

    Logger.debug("Setting up #{input_topic} for #{dataset.id}")
    Elsa.create_topic(@endpoints, input_topic)
    wait_for_topic!(input_topic)

    {input_topic}
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
    IO.inspect(label: "done with load to topic")
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

  defp create_cve_dataset() do
    schema = [
      %{type: "string", name: "timestamp"},
      %{type: "string", name: "messageType"},
      %{type: "json", name: "messageBody"},
      %{type: "string", name: "sourceDevice"}
    ]

    TDG.create_dataset(technical: %{schema: schema, sourceType: "stream"})
  end

  defp create_data_message(dataset, type) do
    payload = %{
      timestamp: DateTime.utc_now(),
      messageType: String.upcase(to_string(type)),
      messageBody: @messages[type],
      sourceDevice: "yidontknow"
    }

    data = TDG.create_data(dataset_id: dataset.id, payload: payload)
    {"", data}
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

  def get_message_count(topic, timeout) do
    full_topic = "streaming:#{topic}"

    Stream.cycle([1])
    |> Enum.reduce_while(0, fn _c, acc ->
      receive do
        %Phoenix.Socket.Message{topic: ^full_topic} = msg->
          {:cont, acc + 1}
      after
        timeout -> {:halt, acc}
      end
    end)
  end
end
