defmodule Reaper.Event.Handlers.DatasetDisableTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.Event.Handlers.DatasetDisable
  alias SmartCity.TestDataGenerator, as: TDG
  alias Quantum.Job
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
      assert [] == Horde.Supervisor.which_children(Reaper.Horde.Supervisor)
    end

    test "does not throw errors if dataset is not running", %{dataset: dataset} do
      assert :ok == DatasetDisable.handle(dataset)
    end

    test "will attempt to find the pid several times", %{dataset: dataset} do
      task = Task.async(fn -> DatasetDisable.handle(dataset) end)
      Process.sleep(500)
      Reaper.Horde.Supervisor.start_data_extract(dataset)

      :ok = Task.await(task)
      assert nil == Reaper.Horde.Registry.lookup(dataset.id)
      assert [] == Horde.Supervisor.which_children(Reaper.Horde.Supervisor)
    end

    test "kills the cache server for the current dataset", %{dataset: dataset} do
      Horde.Supervisor.start_child(Reaper.Horde.Supervisor, {Reaper.Cache, name: dataset.id})
      cache_pid = Reaper.Cache.Registry.lookup(dataset.id)
      assert nil != cache_pid

      assert :ok == DatasetDisable.handle(dataset)

      assert nil == Reaper.Cache.Registry.lookup(dataset.id)
      assert [] == Horde.Supervisor.which_children(Reaper.Horde.Supervisor)
    end

    test "returns error when an error occurs", %{dataset: dataset} do
      allow Reaper.Horde.Registry.lookup(any()), exec: fn _ -> raise("Mistakes were made") end

      assert match?({:error, _}, DatasetDisable.handle(dataset))
    end

    test "stops the dataset job in quantum", %{dataset: dataset} do
      dataset_id = dataset.id |> String.to_atom()

      create_job(dataset_id)

      :ok = DatasetDisable.handle(dataset)

      job = Reaper.Scheduler.find_job(dataset_id)

      assert job.state == :inactive
    end
  end

  defp create_job(dataset_id) do
    Reaper.Scheduler.new_job()
    |> Job.set_name(dataset_id)
    |> Job.set_schedule(Crontab.CronExpression.Parser.parse!("* * * * *"))
    |> Job.set_task(fn -> IO.puts("Test Job is running") end)
    |> Reaper.Scheduler.add_job()
  end
end
