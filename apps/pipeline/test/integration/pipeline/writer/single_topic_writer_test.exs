defmodule Pipeline.Writer.SingleTopicWriterTest do
  use ExUnit.Case
  use Divo
  use Placebo

  alias Pipeline.Writer.SingleTopicWriter
  import SmartCity.TestHelper, only: [eventually: 1]

  @topic Application.get_env(:pipeline, :output_topic)
  @brokers Application.get_env(:pipeline, :elsa_brokers)
  @producer :"pipeline-#{Application.get_env(:pipeline, :producer_name)}"

  setup do
    on_exit(fn ->
      DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)
      |> Enum.map(&elem(&1, 1))
      |> Enum.each(fn pid ->
        Process.monitor(pid)
        DynamicSupervisor.terminate_child(Pipeline.DynamicSupervisor, pid)
        assert_receive {:DOWN, _, _, ^pid, _}
      end)
    end)
  end

  describe "init/2" do
    test "ensures topic exists to write to" do
      assert :ok = SingleTopicWriter.init(app: :pipeline)
      eventually(fn -> assert Elsa.topic?(@brokers, @topic) end)
    end

    test "tracks topic per instance" do
      assert :ok = SingleTopicWriter.init(app: :pipeline)

      eventually(fn ->
        assert Elsa.topic?(@brokers, @topic)
        assert {:ok, @topic} = Registry.meta(Pipeline.Registry, @producer)
      end)
    end

    test "fails if it cannot connect to topic" do
      allow Elsa.topic?(any(), any()), return: false, meck_options: [:passthrough]
      assert :ok = SingleTopicWriter.init(app: :pipeline)

      [{:undefined, pid, _, _}] = DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)
      Process.monitor(pid)

      eventually(fn ->
        assert_receive {:DOWN, _, _, ^pid, {%RuntimeError{message: msg}, _}}
        assert msg == "Timed out waiting for #{@topic} to be available"
      end)
    end
  end

  describe "write/2" do
    test "produces messages to single topic" do
      assert :ok = SingleTopicWriter.init(app: :pipeline)

      [{_, pid, _, _}] = DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)
      Process.monitor(pid)
      assert_receive {:DOWN, _, _, ^pid, :normal}, 2_000

      assert :ok = SingleTopicWriter.write(["foo"], app: :pipeline)

      eventually(fn ->
        assert {:ok, _, messages} = Elsa.fetch(@brokers, @topic)
        assert [%Elsa.Message{value: "foo"}] = messages
      end)
    end
  end
end
