defmodule Forklift.Integration.InitTest do
  use ExUnit.Case
  use Placebo

  import Mox
  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  setup_all do
    Application.put_env(:forklift, :output_topic, "test-topic")
    on_exit(fn -> Application.delete_env(:forklift, :output_topic) end)
  end

  test "starts a dataset topic reader for each dataset view state" do
    test = self()
    expect(MockReader, :init, 2, fn args -> send(test, args[:dataset]) end)
    expect(MockTopic, :init, fn _ -> :ok end)

    dataset1 = TDG.create_dataset(%{id: "view-state-1"})
    dataset2 = TDG.create_dataset(%{id: "view-state-2"})

    allow Brook.get_all_values!(:forklift, :datasets), return: [dataset1, dataset2]
    assert {:ok, _} = Forklift.Init.start_link([])

    assert_receive %SmartCity.Dataset{id: "view-state-1"}
    assert_receive %SmartCity.Dataset{id: "view-state-2"}
  end

  test "initializes output_topic TopicWriter" do
    test = self()
    expect(MockReader, :init, 0, fn _ -> :ok end)
    expect(MockTopic, :init, fn args -> send(test, args[:topic]) end)
    allow Brook.get_all_values!(:forklift, :datasets), return: []

    assert {:ok, _} = Forklift.Init.start_link([])
    assert_receive "test-topic"
  end

  test "terminates after initialization" do
    expect(MockReader, :init, 0, fn _ -> :ok end)
    expect(MockTopic, :init, fn _ -> :ok end)
    allow Brook.get_all_values!(:forklift, :datasets), return: []

    {:ok, pid} = Forklift.Init.start_link([])
    Process.monitor(pid)

    assert_receive {:DOWN, _, _, ^pid, :normal}
  end
end
