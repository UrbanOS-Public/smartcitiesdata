defmodule Pipeline.Reader.DatasetTopicReaderTest do
  use ExUnit.Case
  use Divo
  use Placebo

  alias Pipeline.Reader.DatasetTopicReader
  alias SmartCity.TestDataGenerator, as: TDG

  import SmartCity.TestHelper, only: [eventually: 1]

  @prefix Application.get_env(:pipeline, :input_topic_prefix)
  @brokers Application.get_env(:pipeline, :elsa_brokers)

  describe "init/2" do
    test "ensures topic exists to read from" do
      dataset = TDG.create_dataset(%{id: "test"})
      args = [app: :pipeline, dataset: dataset, handler: Pipeline.TestHandler]

      assert {:ok, _pid} = DatasetTopicReader.init(args)

      eventually(fn ->
        assert {"#{@prefix}-test", 1} in Elsa.Topic.list(@brokers)
      end)
    end

    test "sets reader up to pass messages to a handler" do
      Application.put_env(:smart_city_test, :endpoint, @brokers)

      dataset = TDG.create_dataset(%{id: "read"})
      args = [app: :pipeline, dataset: dataset, handler: Pipeline.TestHandler]
      message = TDG.create_data(%{})

      assert {:ok, _pid} = DatasetTopicReader.init(args)
      eventually(fn -> assert {"#{@prefix}-read", 1} in Elsa.Topic.list(@brokers) end)

      SmartCity.KafkaHelper.send_to_kafka(message, "#{@prefix}-read")

      eventually(fn ->
        assert {:ok, [%Elsa.Message{value: json, topic: "#{@prefix}-read"}]} = Registry.meta(Pipeline.TestRegistry, :messages)
        assert Jason.decode!(json)["payload"]["my_float"] == message.payload["my_float"]
        assert Jason.decode!(json)["payload"]["my_string"] == message.payload["my_string"]
      end)
    end

    test "idempotently sets up reader infrastructure" do
      dataset = TDG.create_dataset(%{id: "idempotent"})
      args = [app: :pipeline, dataset: dataset, handler: Pipeline.TestHandler]

      assert {:ok, pid1} = DatasetTopicReader.init(args)
      Process.monitor(pid1)

      assert {:ok, pid2} = DatasetTopicReader.init(args)
      Process.monitor(pid2)

      eventually(fn ->
        assert {"#{@prefix}-idempotent", 1} in Elsa.Topic.list(@brokers)
        assert_receive {:DOWN, _, _, ^pid1, :normal}
        assert_receive {:DOWN, _, _, ^pid2, :normal}
      end)
    end

    test "fails if it cannot connect to dataset topic" do
      allow Elsa.create_topic(any(), "#{@prefix}-unreachable"), return: :ignore, meck_options: [:passthrough]

      dataset = TDG.create_dataset(%{id: "unreachable"})
      args = [app: :pipeline, dataset: dataset, handler: Pipeline.TestHandler]

      assert {:ok, pid} = DatasetTopicReader.init(args)
      Process.monitor(pid)

      eventually(fn ->
        assert {"#{@prefix}-unreachable", 1} not in Elsa.Topic.list(@brokers)
        assert_receive {:DOWN, _, _, ^pid, {%RuntimeError{message: msg}, _}}
        assert msg == "Timed out waiting for #{@prefix}-unreachable to be available"
      end)
    end
  end
end

defmodule Pipeline.TestHandler do
  use Elsa.Consumer.MessageHandler

  def init(_ \\ []) do
    case Registry.start_link(keys: :unique, name: Pipeline.TestRegistry) do
      {:ok, _} -> {:ok, []}
      {:error, {:already_started, _}} -> {:ok, []}
      error -> {:error, error}
    end
  end

  def handle_messages(messages, state) do
    Registry.put_meta(Pipeline.TestRegistry, :messages, messages)
    {:ack, state}
  end
end
