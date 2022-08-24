defmodule Forklift.InitServerTest do
  use ExUnit.Case
  use Placebo

  import Mox
  alias SmartCity.TestDataGenerator, as: TDG

  @instance_name Forklift.instance_name()

  setup :set_mox_global
  setup :verify_on_exit!

  setup_all do
    Application.put_env(:forklift, :output_topic, "test-topic")
    on_exit(fn -> Application.delete_env(:forklift, :output_topic) end)
  end

  test "starts a dataset topic reader for each dataset view state" do
    test = self()
    dataset1 = TDG.create_dataset(%{id: "view-state-1"})
    dataset2 = TDG.create_dataset(%{id: "view-state-2"})

    allow Brook.get_all_values!(@instance_name, :datasets), return: [dataset1, dataset2]
    stub(MockTopic, :init, fn _ -> :ok end)
    stub(MockReader, :init, fn args -> send(test, args[:dataset]) && :ok end)

    assert {:ok, _} = Forklift.InitServer.start_link(name: :foo)

    assert_receive %SmartCity.Dataset{id: "view-state-1"}, 1000
    assert_receive %SmartCity.Dataset{id: "view-state-2"}, 1000
  end

  test "initializes output_topic TopicWriter" do
    test = self()

    allow Brook.get_all_values!(@instance_name, :datasets), return: []
    stub(MockReader, :init, fn _ -> :ok end)
    stub(MockTopic, :init, fn args -> send(test, args[:topic]) && :ok end)

    assert {:ok, _} = Forklift.InitServer.start_link(name: :bar)
    assert_receive "test-topic"
  end

  test "re-initializes if Pipeline.DynamicSupervisor crashes" do
    test = self()
    dataset1 = TDG.create_dataset(%{id: "restart-1"})
    dataset2 = TDG.create_dataset(%{id: "restart-2"})

    allow Brook.get_all_values!(@instance_name, :datasets), return: [dataset1, dataset2]
    stub(MockTopic, :init, fn _ -> :ok end)

    expect(MockReader, :init, 2, fn _ -> :ok end)
    expect(MockReader, :init, 2, fn args -> send(test, args[:dataset]) && :ok end)

    Forklift.InitServer.start_link(name: :baz)
    DynamicSupervisor.stop(Pipeline.DynamicSupervisor, :test)

    assert_receive dataset1, 1_000
    assert_receive dataset2, 1_000
  end
end
