defmodule DiscoveryStreams.Performance.CveTest do
  use ExUnit.Case
  use Divo
  require Logger

  use DiscoveryStreamsWeb.ChannelCase
  import SmartCity.Event, only: [data_ingest_start: 0]
  import SmartCity.TestHelper

  alias Performance.Cve
  alias Performance.Kafka
  alias Performance.SetupConfig

  @moduletag :performance
  @endpoints Application.get_env(:discovery_streams, :endpoints)
  @input_topic_prefix "transformed"

  setup_all do
    Logger.configure(level: :info)
    Agent.start(fn -> 0 end, name: :iterations_counter)

    :ok
  end

  @tag timeout: :infinity
  test "run performance test" do
    _map_messages = Cve.generate_messages(1_000, :map)
    spat_messages = Cve.generate_messages(1_000, :spat)
    bsm_messages = Cve.generate_messages(1_000, :bsm)

    {scenarios, _} = [{"spat", spat_messages}, {"bsm", bsm_messages}]
    |> Kafka.generate_consumer_scenarios()
    |> Map.split(["spat.lmb.lmw.lmib.lpc.lpb", "bsm.lmb.lmw.lmib.lpc.lpb"])

    Benchee.run(
      %{
        "kafka" => fn {dataset, expected_count, input_topic, socket} = _output_from_before_each ->

          eventually(fn ->
            current_total = AccumulatorTransportSocket.get_message_count(socket.transport_pid)

            PerfLogger.debug(fn -> "output is #{current_total} of #{expected_count}" end)

            assert current_total >= expected_count
          end, 100, 5000)

          {dataset, input_topic, socket}
        end
      },
      inputs: scenarios,
      before_scenario: fn %SetupConfig{messages: messages} = _parameters_from_inputs ->
        messages
      end,
      before_each: fn {messages, count} = _output_from_before_scenario ->
        dataset = Cve.create_dataset()

        iteration = Agent.get_and_update(:iterations_counter, fn s -> {s, s + 1} end)

        {input_topic} = Kafka.setup_topics([@input_topic_prefix], dataset, @endpoints)

        Brook.Event.send(:discovery_streams, data_ingest_start(), :author, dataset)

        socket = join_stream(dataset)

        Kafka.load_messages(@endpoints, dataset, input_topic, messages, count, 10_000)

        {dataset, count, input_topic, socket}
      end,
      after_each: fn {dataset, input_topic, socket} = _output_from_run ->
          DiscoveryStreams.Stream.Supervisor.terminate_child(dataset.id)

          leave_stream(socket)

          Elsa.delete_topic(@endpoints, input_topic)
      end,
      time: 30,
      memory_time: 1,
      warmup: 0
    )
  end

  defp join_stream(dataset) do
    eventually(fn ->
      assert {:ok, _, socket} =
        DiscoveryStreamsWeb.UserSocket
        |> socket()
        |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset.technical.systemName}")

      Process.unlink(socket.channel_pid)
      :ok = close(socket)
    end,
      100,
      5000
    )

    {:ok, tpid} = GenServer.start_link(AccumulatorTransportSocket, 0)

    {:ok, _, socket} = DiscoveryStreamsWeb.UserSocket
    |> socket()
    |> Map.put(:transport_pid, tpid)
    |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset.technical.systemName}")

    Process.sleep(10_000)

    socket
  end

  defp leave_stream(socket) do
    Process.unlink(socket.transport_pid)
    Process.exit(socket.transport_pid, :normal)

    Process.unlink(socket.channel_pid)
    :ok = close(socket)
  end
end

defmodule AccumulatorTransportSocket do
  use GenServer

  def init(initial_count) do
    {:ok, initial_count}
  end

  def get_message_count(pid) do
    GenServer.call(pid, {:get_message_count})
  end

  def handle_info(%Phoenix.Socket.Message{}, state) do
    {:noreply, state + 1}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def handle_call({:get_message_count}, _, state) do
    {:reply, state, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
