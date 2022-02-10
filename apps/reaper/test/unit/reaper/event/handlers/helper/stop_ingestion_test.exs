defmodule Reaper.Event.Handlers.Helper.StopIngestionTest do
  use ExUnit.Case
  use Placebo

  alias Reaper.Event.Handlers.Helper.StopIngestion
  alias SmartCity.TestDataGenerator, as: TDG
  alias Quantum.Job
  @moduletag capture_log: true

  setup do
    TestHelper.start_horde()
    {:ok, scheduler} = Reaper.Scheduler.start_link()

    allow(Reaper.DataExtract.Processor.process(any()),
      exec: fn _dataset -> Process.sleep(10 * 60_000) end
    )

    ingestion = TDG.create_ingestion(%{id: "ds-to-kill"})

    on_exit(fn ->
      TestHelper.assert_down(scheduler)
    end)

    [ingestion: ingestion]
  end

  describe "handle/1" do
    test "kills any process for the current ingestion", %{ingestion: ingestion} do
      Reaper.Horde.Supervisor.start_data_extract(ingestion)
      horde_pid = Reaper.Horde.Registry.lookup(ingestion.id)
      assert nil != horde_pid

      assert :ok == StopIngestion.stop_horde_and_cache(ingestion.id)

      assert nil == Reaper.Horde.Registry.lookup(ingestion.id)
      assert [] == Horde.DynamicSupervisor.which_children(Reaper.Horde.Supervisor)
    end

    test "does not throw errors if ingestion is not running", %{ingestion: ingestion} do
      assert :ok == StopIngestion.stop_horde_and_cache(ingestion.id)
    end

    test "will attempt to find the pid several times", %{ingestion: ingestion} do
      task = Task.async(fn -> StopIngestion.stop_horde_and_cache(ingestion.id) end)
      Process.sleep(500)
      Reaper.Horde.Supervisor.start_data_extract(ingestion)

      :ok = Task.await(task)
      assert nil == Reaper.Horde.Registry.lookup(ingestion.id)
      assert [] == Horde.DynamicSupervisor.which_children(Reaper.Horde.Supervisor)
    end

    test "kills the cache server for the current ingestion", %{ingestion: ingestion} do
      Horde.DynamicSupervisor.start_child(
        Reaper.Horde.Supervisor,
        {Reaper.Cache, name: ingestion.id}
      )

      cache_pid = Reaper.Cache.Registry.lookup(ingestion.id)
      assert nil != cache_pid

      assert :ok == StopIngestion.stop_horde_and_cache(ingestion.id)

      assert nil == Reaper.Cache.Registry.lookup(ingestion.id)
      assert [] == Horde.DynamicSupervisor.which_children(Reaper.Horde.Supervisor)
    end

    test "returns error when an error occurs", %{ingestion: ingestion} do
      allow(Reaper.Horde.Registry.lookup(any()), exec: fn _ -> raise("Mistakes were made") end)

      assert match?({:error, _}, StopIngestion.stop_horde_and_cache(ingestion.id))
    end

    test "stops the ingestion job in quantum", %{ingestion: ingestion} do
      dataset_id = ingestion.id |> String.to_atom()

      create_job(dataset_id)

      :ok = StopIngestion.deactivate_quantum_job(ingestion.id)

      job = Reaper.Scheduler.find_job(dataset_id)

      assert job.state == :inactive
    end

    test "should delete the quantum job", %{ingestion: ingestion} do
      dataset_id = ingestion.id |> String.to_atom()

      create_job(dataset_id)

      :ok = StopIngestion.delete_quantum_job(ingestion.id)

      assert nil == Reaper.Scheduler.find_job(dataset_id)
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
