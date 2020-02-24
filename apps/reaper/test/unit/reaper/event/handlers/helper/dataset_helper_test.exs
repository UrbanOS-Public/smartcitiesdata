defmodule Reaper.Event.Handlers.Helper.DatasetHelperTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.Event.Handlers.Helper.DatasetHelper
  alias SmartCity.TestDataGenerator, as: TDG
  alias Quantum.Job

  @moduletag capture_log: true

  setup do
    TestHelper.start_horde()
    {:ok, scheduler} = Reaper.Scheduler.start_link()
    allow Reaper.DataExtract.Processor.process(any()), exec: fn _dataset -> Process.sleep(10 * 60_000) end
    dataset = TDG.create_dataset(id: Faker.UUID.v4())

    on_exit(fn ->
      TestHelper.assert_down(scheduler)
    end)

    [dataset: dataset]
  end

  test "will attempt to find the pid several times", %{dataset: dataset} do
    task = Task.async(fn -> stop_dataset(dataset.id) end)
    Process.sleep(500)
    Reaper.Horde.Supervisor.start_data_extract(dataset)

    :ok = Task.await(task)
    assert nil == Reaper.Horde.Registry.lookup(dataset.id)
    assert [] == Horde.DynamicSupervisor.which_children(Reaper.Horde.Supervisor)
  end

  test "kills the cache server for the current dataset", %{dataset: dataset} do
    Horde.DynamicSupervisor.start_child(Reaper.Horde.Supervisor, {Reaper.Cache, name: dataset.id})
    cache_pid = Reaper.Cache.Registry.lookup(dataset.id)
    assert nil != cache_pid

    assert :ok == kill_cache(dataset.id)

    assert nil == Reaper.Cache.Registry.lookup(dataset.id)
    assert [] == Horde.DynamicSupervisor.which_children(Reaper.Horde.Supervisor)
  end

  test "stops the dataset job in quantum", %{dataset: dataset} do
    dataset_id = dataset.id |> String.to_atom()
    create_job(dataset_id)
    :ok = DatasetHelper.deactivate_quantum_job(dataset.id)
    job = Reaper.Scheduler.find_job(dataset_id)
    assert job.state == :inactive
  end

  defp create_job(dataset_id) do
    Reaper.Scheduler.new_job()
    |> Job.set_name(dataset_id)
    |> Job.set_schedule(Crontab.CronExpression.Parser.parse!("* * * * *"))
    |> Job.set_task(fn -> IO.puts("Test Job is running") end)
    |> Reaper.Scheduler.add_job()
  end

  defp stop_dataset(dataset_id) do
    DatasetHelper.retry_stopping_dataset(Reaper.Horde.Registry, dataset_id)
  end

  defp kill_cache(dataset_id) do
    DatasetHelper.retry_stopping_dataset(Reaper.Cache.Registry, dataset_id)
  end
end
