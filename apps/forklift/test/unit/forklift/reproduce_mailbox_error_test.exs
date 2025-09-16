defmodule Forklift.ReproduceMailboxErrorTest do
  use ExUnit.Case
  import Mox
  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  setup_all do
    Application.put_env(:forklift, :output_topic, "test-topic")
    on_exit(fn -> Application.delete_env(:forklift, :output_topic) end)
  end

  test "demonstrates the exact same mailbox timeout error" do
    test = self()
    dataset1 = TDG.create_dataset(%{id: "timeout-demo-1"})
    dataset2 = TDG.create_dataset(%{id: "timeout-demo-2"})

    # Mock to return datasets
    stub(BrookMock, :get_all_values!, fn _, _ -> [dataset1, dataset2] end)
    stub(MockTopic, :init, fn _ -> :ok end)

    # Expect MockReader.init to be called during initial startup
    expect(MockReader, :init, 2, fn args ->
      send(test, {:startup, args[:dataset]})
      :ok
    end)

    # Start InitServer
    {:ok, _pid} = Forklift.InitServer.start_link(name: :timeout_demo)

    # These should work during initial startup
    assert_receive {:startup, ^dataset1}, 1_000
    assert_receive {:startup, ^dataset2}, 1_000

    # Now set up expectations for restart behavior
    expect(MockReader, :init, 2, fn args ->
      send(test, {:restart, args[:dataset]})
      :ok
    end)

    # Stop supervisor to trigger restart
    DynamicSupervisor.stop(Pipeline.DynamicSupervisor, :test)

    # These will fail with "Assertion failed, no matching message after 1000ms"
    # This demonstrates the exact same error as the original failing test
    assert_receive {:restart, ^dataset1}, 2_000
    assert_receive {:restart, ^dataset2}, 2_000
  end

  @tag :skip
  test "simplified version showing the core issue" do
    dataset1 = TDG.create_dataset(%{id: "simple-1"})

    stub(BrookMock, :get_all_values!, fn _, _ -> [dataset1] end)
    stub(MockTopic, :init, fn _ -> :ok end)
    stub(MockReader, :init, fn _ -> :ok end)

    # Start and immediately crash the supervisor
    Forklift.InitServer.start_link(name: :simple_test)
    DynamicSupervisor.stop(Pipeline.DynamicSupervisor, :test)

    # The issue: after supervisor crash, no re-initialization happens
    # Or the re-initialization doesn't work properly
    refute_receive _, 1_000
  end
end
