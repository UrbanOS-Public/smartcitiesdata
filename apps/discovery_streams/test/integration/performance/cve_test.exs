defmodule DiscoveryStreams.Performance.CveTest do
  use ExUnit.Case
  use Performance.BencheeCase
  use DiscoveryStreamsWeb.ChannelCase

  import SmartCity.Event, only: [data_ingest_start: 0]
  import SmartCity.TestHelper

  @endpoints Application.get_env(:discovery_streams, :endpoints)
  @input_topic_prefix "transformed"

  @tag timeout: :infinity
  test "run performance test", %{benchee_run: benchee_run} do
    _map_messages = Cve.generate_messages(1_000, :map)
    spat_messages = Cve.generate_messages(1_000, :spat)
    bsm_messages = Cve.generate_messages(1_000, :bsm)

    {scenarios, _} = [{"spat", spat_messages}, {"bsm", bsm_messages}]
    |> Kafka.generate_consumer_scenarios()
    |> Map.split(["spat.lmb.lmw.lmib.lpc.lpb", "bsm.lmb.lmw.lmib.lpc.lpb"])

    benchee_opts = [
      inputs: scenarios,
      before_scenario: fn %SetupConfig{} = parameters_from_inputs ->
        {messages, kafka_parameters} = Map.split(parameters_from_inputs, [:messages])

        messages.messages
      end,
      before_each: fn {messages, count} = _output_from_before_scenario ->
        dataset = Cve.create_dataset()
        {input_topic} = Kafka.setup_topics([@input_topic_prefix], dataset, @endpoints)

        Brook.Event.send(:discovery_streams, data_ingest_start(), :author, dataset)
        socket = join_stream(dataset)
        Kafka.load_messages(@endpoints, dataset, input_topic, messages, count, 10_000)

        {dataset, count, input_topic, socket}
      end,
      under_test: fn {dataset, expected_count, input_topic, socket} ->
        eventually(fn ->
          current_total = AccumulatorTransportSocket.get_message_count(socket.transport_pid)

          assert current_total >= expected_count
        end, 100, 5000)

        {dataset, input_topic, socket}
      end,
      after_each: fn {dataset, input_topic, socket} = _output_from_run ->
        DiscoveryStreams.Stream.Supervisor.terminate_child(dataset.id)

        leave_stream(socket)

        Elsa.delete_topic(@endpoints, input_topic)
      end,
      time: 30,
      memory_time: 1,
      warmup: 0
    ]

    benchee_run.(benchee_opts)
  end

  defp join_stream(dataset) do
    wait_until_stream_is_joinable(dataset)

    {:ok, _, socket} = do_join(dataset)

    Process.sleep(10_000)

    socket
  end

  defp wait_until_stream_is_joinable(dataset) do
    eventually(fn ->
      {:ok, _, socket} = do_join(dataset)

      leave_stream(socket)
    end,
      100,
      5000
    )
  end

  defp do_join(dataset) do
    {:ok, tpid} = GenServer.start_link(AccumulatorTransportSocket, 0)

    DiscoveryStreamsWeb.UserSocket
    |> socket()
    |> Map.put(:transport_pid, tpid)
    |> subscribe_and_join(DiscoveryStreamsWeb.StreamingChannel, "streaming:#{dataset.technical.systemName}")
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
  require Logger

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
