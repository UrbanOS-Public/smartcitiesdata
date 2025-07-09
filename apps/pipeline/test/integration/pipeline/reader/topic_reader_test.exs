defmodule Pipeline.Reader.TopicReaderTest do
  use ExUnit.Case
  use Divo
  import Mox

  alias Pipeline.Reader.TopicReader
  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.TestHelper, only: [eventually: 1, eventually: 3]

  @brokers Application.get_env(:pipeline, :elsa_brokers)

  setup :verify_on_exit!

  setup_all do
    {:ok, pid} = Registry.start_link(keys: :unique, name: Pipeline.TestRegistry)

    on_exit(fn ->
      ref = Process.monitor(pid)
      Process.exit(pid, :shutdown)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)
  end

  describe "init/1" do
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

    test "ensures topic exists to read from" do
      args = [
        instance: :pipeline,
        connection: :"foo-0",
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "init-0",
        retry_count: 10,
        retry_delay: 1
      ]

      assert :ok = TopicReader.init(args)

      eventually(fn -> assert Elsa.topic?(@brokers, "init-0") end)
    end

    test "sets reader up to pass messages to a handler" do
      message = TDG.create_data(%{})

      args = [
        instance: :pipeline,
        connection: :"foo-1",
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "init-1",
        retry_count: 10,
        retry_delay: 1,
        topic_subscriber_config: [
          begin_offset: :earliest,
          offset_reset_policy: :reset_to_earliest
        ]
      ]

      assert :ok = TopicReader.init(args)
      eventually(fn -> assert Elsa.topic?(@brokers, "init-1") end)

      Application.put_env(:smart_city_test, :endpoint, @brokers)
      SmartCity.KafkaHelper.send_to_kafka(message, "init-1")

      eventually(
        fn ->
          assert {:ok, [%Elsa.Message{value: json, topic: "init-1"}]} = Registry.meta(Pipeline.TestRegistry, :messages)

          assert Jason.decode!(json)["payload"]["my_float"] == message.payload["my_float"]
          assert Jason.decode!(json)["payload"]["my_string"] == message.payload["my_string"]
        end,
        5_000,
        5
      )
    end

    test "tracks reader infrastructure" do
      args = [
        instance: :pipeline,
        connection: :"foo-2",
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "init-2",
        retry_count: 10,
        retry_delay: 1
      ]

      :ok = TopicReader.init(args)

      assert [{:undefined, pid, _, _}] = DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)

      assert [{^pid, _}] = Registry.lookup(Pipeline.Registry, :"pipeline-init-2-pipeline-supervisor")
    end

    test "idempotently sets up reader infrastructure" do
      args = [
        instance: :pipeline,
        connection: :"foo-3",
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "init-3",
        retry_count: 10,
        retry_delay: 1
      ]

      :ok = TopicReader.init(args)
      [{:undefined, pid, _, _}] = DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)

      assert :ok = TopicReader.init(args)

      assert [{:undefined, ^pid, _, _}] = DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)

      assert [{^pid, _}] = Registry.lookup(Pipeline.Registry, :"pipeline-init-3-pipeline-supervisor")
    end

    test "returns error tuple if topic not available" do
      expect(ElsaMock, :create_topic, fn _, "init-fail" -> :ignore end)

      args = [
        instance: :pipeline,
        connection: :"foo-fail",
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "init-fail",
        retry_count: 10,
        retry_delay: 1
      ]

      assert {:error, "Timed out waiting for init-fail to be available"} = TopicReader.init(args)
    end
  end

  describe "terminate/1" do
    test "tears down reader infrastructure" do
      init_args = [
        instance: :pipeline,
        connection: :"bar-0",
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "term-0",
        retry_count: 10,
        retry_delay: 1
      ]

      :ok = TopicReader.init(init_args)

      eventually(fn -> assert Elsa.topic?(@brokers, "term-0") end)
      [{pid, _}] = Registry.lookup(Pipeline.Registry, :"pipeline-term-0-pipeline-supervisor")
      assert Process.alive?(pid)

      TopicReader.terminate(instance: :pipeline, topic: "term-0")

      refute Process.alive?(pid)
      eventually(fn -> assert Registry.lookup(Pipeline.Registry, :"pipeline-term-0-pipeline-supervisor") == [] end)
    end

    test "returns error tuple if infrastructure cannot be torn down" do
      assert {:error, "Cannot find pid to terminate: []"} = TopicReader.terminate(instance: :pipeline, topic: "foo")
    end
  end
end
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "init-2",
        retry_count: 10,
        retry_delay: 1
      ]

      :ok = TopicReader.init(args)

      assert [{:undefined, pid, _, _}] = DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)

      assert [{^pid, _}] = Registry.lookup(Pipeline.Registry, :"pipeline-init-2-pipeline-supervisor")
    end

    test "idempotently sets up reader infrastructure" do
      args = [
        instance: :pipeline,
        connection: :"foo-3",
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "init-3",
        retry_count: 10,
        retry_delay: 1
      ]

      :ok = TopicReader.init(args)
      [{:undefined, pid, _, _}] = DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)

      assert :ok = TopicReader.init(args)

      assert [{:undefined, ^pid, _, _}] = DynamicSupervisor.which_children(Pipeline.DynamicSupervisor)

      assert [{^pid, _}] = Registry.lookup(Pipeline.Registry, :"pipeline-init-3-pipeline-supervisor")
    end

    test "returns error tuple if topic not available" do
      allow(Elsa.create_topic(any(), "init-fail"), return: :ignore, meck_options: [:passthrough])

      args = [
        instance: :pipeline,
        connection: :"foo-fail",
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "init-fail",
        retry_count: 10,
        retry_delay: 1
      ]

      assert {:error, "Timed out waiting for init-fail to be available"} = TopicReader.init(args)
    end
  end

  describe "terminate/1" do
    test "tears down reader infrastructure" do
      init_args = [
        instance: :pipeline,
        connection: :"bar-0",
        endpoints: @brokers,
        handler: Pipeline.TestHandler,
        topic: "term-0",
        retry_count: 10,
        retry_delay: 1
      ]

      :ok = TopicReader.init(init_args)

      eventually(fn -> assert Elsa.topic?(@brokers, "term-0") end)
      [{pid, _}] = Registry.lookup(Pipeline.Registry, :"pipeline-term-0-pipeline-supervisor")
      assert Process.alive?(pid)

      TopicReader.terminate(instance: :pipeline, topic: "term-0")

      refute Process.alive?(pid)
      eventually(fn -> assert Registry.lookup(Pipeline.Registry, :"pipeline-term-0-pipeline-supervisor") == [] end)
    end

    test "returns error tuple if infrastructure cannot be torn down" do
      assert {:error, "Cannot find pid to terminate: []"} = TopicReader.terminate(instance: :pipeline, topic: "foo")
    end
  end
end
