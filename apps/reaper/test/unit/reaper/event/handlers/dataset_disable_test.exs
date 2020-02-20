defmodule Reaper.Event.Handlers.DatasetDisableTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.Event.Handlers.DatasetDisable
  alias SmartCity.TestDataGenerator, as: TDG
  @moduletag capture_log: true

  setup do
    TestHelper.start_horde()
    {:ok, scheduler} = Reaper.Scheduler.start_link()
    allow Reaper.DataExtract.Processor.process(any()), exec: fn _dataset -> Process.sleep(10 * 60_000) end
    dataset = TDG.create_dataset(id: "ds-to-kill")

    on_exit(fn ->
      TestHelper.assert_down(scheduler)
    end)

    [dataset: dataset]
  end

  describe "handle/1" do
    test "kills any process for the current dataset", %{dataset: dataset} do
      Reaper.Horde.Supervisor.start_data_extract(dataset)
      horde_pid = Reaper.Horde.Registry.lookup(dataset.id)
      assert nil != horde_pid

      assert :ok == DatasetDisable.handle(dataset)

      assert nil == Reaper.Horde.Registry.lookup(dataset.id)
      assert [] == Horde.DynamicSupervisor.which_children(Reaper.Horde.Supervisor)
    end

    test "does not throw errors if dataset is not running", %{dataset: dataset} do
      assert :ok == DatasetDisable.handle(dataset)
    end

    test "returns error when an error occurs", %{dataset: dataset} do
      allow Reaper.Horde.Registry.lookup(any()), exec: fn _ -> raise("Mistakes were made") end

      assert match?({:error, _}, DatasetDisable.handle(dataset))
    end
  end
end
