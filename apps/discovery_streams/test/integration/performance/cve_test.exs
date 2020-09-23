defmodule DiscoveryStreams.Performance.CveTest do
  use ExUnit.Case
  use Performance.BencheeCase,
    otp_app: :discovery_streams,
    endpoints: Application.get_env(:discovery_streams, :endpoints),
    topic_prefixes: ["transformed"],
    log_level: :warn

  use DiscoveryStreamsWeb.ChannelCase

  import SmartCity.Event, only: [data_ingest_start: 0]
  import SmartCity.TestHelper

  @tag timeout: :infinity
  test "run performance test" do
    # map_messages = Cve.generate_messages(10_000, :map)
    spat_messages = Cve.generate_messages(10_000, :spat)
    bsm_messages = Cve.generate_messages(10_000, :bsm)

    {scenarios, _} = [{"spat", spat_messages}, {"bsm", bsm_messages}]
    |> Kafka.generate_consumer_scenarios()
    |> Map.split(["spat.lmb.lmw.lmib.lpc.lpb", "bsm.lmb.lmw.lmib.lpc.lpb"])

    benchee_opts = [
      inputs: scenarios,
      before_scenario: fn input ->
        tune_consumer_parameters(input)

        input.messages
      end,
      before_each: fn messages ->
        dataset = Cve.create_dataset()
        count = length(messages)

        {input_topic} = create_kafka_topics(dataset)

        Brook.Event.send(:discovery_streams, data_ingest_start(), :author, dataset)
        socket = join_stream(dataset)

        load_messages(dataset, input_topic, messages)

        {dataset, count, socket}
      end,
      under_test: fn {dataset, expected_count, socket} ->
        eventually(fn ->
          current_count = AccumulatorTransportSocket.get_message_count(socket.transport_pid)

          Logger.info(fn -> "Measured record counts #{current_count} v. #{expected_count}" end)

          assert current_count >= expected_count
        end, 100, 5000)

        {dataset, socket}
      end,
      after_each: fn {dataset, socket} = _output_from_run ->
        DiscoveryStreams.Stream.Supervisor.terminate_child(dataset.id)

        leave_stream(socket)

        delete_kafka_topics(dataset)
      end,
      time: 30,
      memory_time: 1,
      warmup: 0
    ]

    benchee_run(benchee_opts)
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
