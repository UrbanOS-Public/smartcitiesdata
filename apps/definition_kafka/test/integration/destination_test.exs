defmodule Kafka.Topic.DestinationTest do
  use ExUnit.Case
  use Divo

  require Temp.Env
  import AssertAsync

  @endpoints [localhost: 9092]
  @moduletag integration: true, divo: true

  setup do
    test = self()

    handler = fn event, measurements, metadata, config ->
      send(test, {:telemetry_event, event, measurements, metadata, config})
    end

    :telemetry.attach(__MODULE__, [:destination, :kafka, :write], handler, %{})
    on_exit(fn -> :telemetry.detach(__MODULE__) end)

    Process.flag(:trap_exit, true)
    :ok
  end

  describe "start_link/2" do
    test "creates topic in Kafka" do
      topic = Kafka.Topic.new!(endpoints: @endpoints, name: "create-me")
      {:ok, pid} = Destination.start_link(topic, context([]))

      assert_async debug: true do
        assert Elsa.topic?(@endpoints, topic.name)
      end

      assert_down(pid)
    end

    test "creates topic with configurable number of partitions" do
      topic = Kafka.Topic.new!(endpoints: @endpoints, name: "partitioned", partitions: 3)
      {:ok, pid} = Destination.start_link(topic, context([]))

      assert_async debug: true do
        assert Elsa.topic?(@endpoints, topic.name)
        assert Elsa.Util.partition_count(@endpoints, topic.name) == 3
      end

      assert_down(pid)
    end
  end

  describe "write/2" do
    test "produces messages to Kafka" do
      topic = Kafka.Topic.new!(endpoints: @endpoints, name: "write-me")
      {:ok, pid} = Destination.start_link(topic, context([]))

      assert :ok = Destination.write(topic, pid, ["one", "two", "three"])

      assert_async debug: true do
        assert Elsa.topic?(@endpoints, topic.name)
        {:ok, _, messages} = Elsa.fetch(@endpoints, topic.name)
        assert ["one", "two", "three"] == Enum.map(messages, & &1.value)
      end

      assert_down(pid)
    end

    test "encodes maps to JSON before producing to Kafka" do
      topic = Kafka.Topic.new!(endpoints: @endpoints, name: "write-maps")
      {:ok, pid} = Destination.start_link(topic, context([]))

      assert :ok = Destination.write(topic, pid, [%{one: 1}, %{two: 2}])

      assert_async debug: true do
        assert Elsa.topic?(@endpoints, topic.name)
        {:ok, _, messages} = Elsa.fetch(@endpoints, topic.name)

        assert [{"", ~s|{"one":1}|}, {"", ~s|{"two":2}|}] ==
                 Enum.map(messages, &{&1.key, &1.value})
      end

      assert_down(pid)
    end

    test "keys message off topic's key_path field" do
      topic = Kafka.Topic.new!(endpoints: @endpoints, name: "key-me", key_path: ["a", "b"])
      {:ok, pid} = Destination.start_link(topic, context([]))

      input = [%{"a" => %{"b" => "1"}}, %{"a" => %{"b" => "2"}}]
      assert :ok = Destination.write(topic, pid, input)

      assert_async debug: true do
        assert Elsa.topic?(@endpoints, topic.name)
        {:ok, _, messages} = Elsa.fetch(@endpoints, topic.name)

        # TOODOO keys can only be binary?
        assert [{"1", ~s|{"a":{"b":"1"}}|}, {"2", ~s|{"a":{"b":"2"}}|}] =
                 Enum.map(messages, &{&1.key, &1.value})
      end

      assert_down(pid)
    end
  end

  describe "stop/1" do
    test "stops the destination topic process" do
      topic = Kafka.Topic.new!(endpoints: @endpoints, name: "stop-me")
      {:ok, pid} = Destination.start_link(topic, context([]))

      assert_async debug: true do
        assert Elsa.topic?(@endpoints, topic.name)
      end

      assert :ok = Destination.stop(topic, pid)

      refute Process.alive?(pid)
    end
  end

  describe "delete/1" do
    test "deletes topic from Kafka" do
      {:ok, topic} = Kafka.Topic.new(endpoints: @endpoints, name: "delete-me")

      Elsa.create_topic(@endpoints, topic.name)

      assert_async debug: true do
        assert Elsa.topic?(@endpoints, topic.name)
      end

      assert :ok = Destination.delete(topic)

      assert_async debug: true do
        refute Elsa.topic?(@endpoints, topic.name)
      end
    end

    test "returns error tuple if topic cannot be deleted" do
      topic = Kafka.Topic.new!(endpoints: @endpoints, name: "never-existed")
      assert {:error, {:unknown_topic_or_partition, _}} = Destination.delete(topic)
    end
  end

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, _, _, _}
  end

  defp context(overrides) do
    [dictionary: Dictionary.from_list([]), dataset_id: "foo", subset_id: "bar"]
    |> Keyword.merge(overrides)
    |> Destination.Context.new!()
  end
end
