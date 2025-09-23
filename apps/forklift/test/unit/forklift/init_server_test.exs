defmodule Forklift.InitServerTest do
  use ExUnit.Case
  import Mox
  alias SmartCity.TestDataGenerator, as: TDG

  @instance_name Forklift.instance_name()

  import Forklift.Test.BrookBehaviour

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

    # Use meck for this test to ensure it doesn't conflict with the restart test
    :meck.new(Forklift.Datasets, [:passthrough])
    :meck.expect(Forklift.Datasets, :get_all!, fn -> [dataset1, dataset2] end)

    on_exit(fn ->
      try do
        :meck.unload(Forklift.Datasets)
      catch
        :error, {:not_mocked, _} -> :ok
      end
    end)

    stub(MockTopic, :init, fn _ -> :ok end)
    stub(MockReader, :init, fn args -> send(test, args[:dataset]) && :ok end)

    assert {:ok, _} = Forklift.InitServer.start_link(name: :foo)

    assert_receive %SmartCity.Dataset{id: "view-state-1"}, 1000
    assert_receive %SmartCity.Dataset{id: "view-state-2"}, 1000
  end

  test "initializes output_topic TopicWriter" do
    test = self()

    # Use meck for consistency
    :meck.new(Forklift.Datasets, [:passthrough])
    :meck.expect(Forklift.Datasets, :get_all!, fn -> [] end)

    on_exit(fn ->
      try do
        :meck.unload(Forklift.Datasets)
      catch
        :error, {:not_mocked, _} -> :ok
      end
    end)

    stub(MockReader, :init, fn _ -> :ok end)
    stub(MockTopic, :init, fn args -> send(test, args[:topic]) && :ok end)

    assert {:ok, _} = Forklift.InitServer.start_link(name: :bar)
    assert_receive "test-topic"
  end

  test "re-initializes if Pipeline.DynamicSupervisor crashes" do
    test = self()
    dataset1 = TDG.create_dataset(%{id: "restart-1"})
    dataset2 = TDG.create_dataset(%{id: "restart-2"})

    # Mock Forklift.Datasets directly instead of Brook
    :meck.new(Forklift.Datasets, [:passthrough])
    :meck.expect(Forklift.Datasets, :get_all!, fn -> [dataset1, dataset2] end)

    stub(MockTopic, :init, fn _ -> :ok end)

    # Use a simple flag to distinguish startup vs restart calls
    startup_complete = :ets.new(:startup_flag, [:public, :named_table])
    :ets.insert(startup_complete, {:startup_done, false})

    # Clean up ETS table and meck when test finishes
    on_exit(fn ->
      if :ets.info(startup_complete) != :undefined, do: :ets.delete(startup_complete)

      try do
        :meck.unload(Forklift.Datasets)
      catch
        :error, {:not_mocked, _} -> :ok
      end
    end)

    stub(MockReader, :init, fn args ->
      try do
        case :ets.lookup(startup_complete, :startup_done) do
          [{:startup_done, false}] ->
            # First two calls are during startup - just return :ok
            :ok

          [{:startup_done, true}] ->
            # Subsequent calls are during restart - send the dataset
            send(test, args[:dataset])
            :ok

          [] ->
            # Table might be deleted, just return :ok
            :ok
        end
      rescue
        ArgumentError ->
          # ETS table was deleted, just return :ok
          :ok
      end
    end)

    {:ok, _pid} = Forklift.InitServer.start_link(name: :baz)

    # Wait a moment for startup to complete, then mark it done
    Process.sleep(100)
    :ets.insert(startup_complete, {:startup_done, true})

    # Stop the supervisor to trigger restart
    DynamicSupervisor.stop(Pipeline.DynamicSupervisor, :test)

    # The InitServer should automatically detect the supervisor crash and re-initialize
    assert_receive ^dataset1, 5_000
    assert_receive ^dataset2, 5_000
  end
end
