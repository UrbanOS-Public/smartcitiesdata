defmodule Pipeline.Writer.TopicWriterTest do
  use ExUnit.Case
  use Divo
  import Mox
  alias Pipeline.Writer.TopicWriter
  import SmartCity.TestHelper, only: [eventually: 1]

  @topic Application.get_env(:pipeline, :output_topic)
  @brokers Application.get_env(:pipeline, :elsa_brokers)
  @producer Application.get_env(:pipeline, :producer_name)

  setup :verify_on_exit!

  setup do
    Mox.stub_with(ElsaMock, Elsa)

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
      config = [
        instance: :pipeline,
        producer_name: @producer,
        endpoints: @brokers,
        topic: @topic
      ]

      assert :ok = TopicWriter.init(config)
      eventually(fn -> assert Elsa.topic?(@brokers, @topic) end)
    end

    test "tracks topic per instance" do
      config = [
        instance: :pipeline,
        producer_name: @producer,
        endpoints: @brokers,
        topic: @topic
      ]

      assert :ok = TopicWriter.init(config)

      eventually(fn ->
        assert Elsa.topic?(@brokers, @topic)
        assert {:ok, @topic} = Registry.meta(Pipeline.Registry, :"pipeline-#{@producer}")
      end)
    end

    test "fails if it cannot connect to topic" do
      expect(ElsaMock, :topic?, fn _, _ -> false end)

      config = [
        instance: :pipeline,
        producer_name: @producer,
        endpoints: @brokers,
        topic: @topic,
        retry_count: 1,
        retry_delay: 10
      ]

      assert :ok = TopicWriter.init(config)

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
      config = [
        instance: :pipeline,
        producer_name: @producer,
        endpoints: @brokers,
        topic: @topic
      ]

      assert :ok = TopicWriter.init(config)

      # [{_, pid, _, _}] = DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)
      # Process.monitor(pid)
      # assert_receive {:DOWN, _, _, ^pid, :normal}, 2_000

      eventually(fn ->
        assert Elsa.topic?(@brokers, @topic)
        assert {:ok, @topic} = Registry.meta(Pipeline.Registry, :"pipeline-#{@producer}")
      end)

      assert :ok = TopicWriter.write(["foo"], instance: :pipeline, producer_name: @producer)
      assert :ok = TopicWriter.write(["bar", "baz"], instance: :pipeline, producer_name: @producer)

      eventually(fn ->
        assert {:ok, _, messages} = Elsa.fetch(@brokers, @topic)
        assert [%Elsa.Message{value: "foo"}, %Elsa.Message{value: "bar"}, %Elsa.Message{value: "baz"}] = messages
      end)
    end
  end

  test "should delete the topic when delete topic is called" do
    topic = "transformed-#{Faker.UUID.v4()}"

    config = [
      instance: :pipeline,
      producer_name: @producer,
      endpoints: @brokers,
      topic: topic
    ]

    assert :ok = TopicWriter.init(config)

    eventually(fn ->
      assert true == Elsa.Topic.exists?(@brokers, topic)
    end)

    assert :ok = TopicWriter.delete(config)

    eventually(fn ->
      assert false == Elsa.topic?(@brokers, topic)
    end)
  end
end
