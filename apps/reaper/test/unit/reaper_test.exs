defmodule ReaperTests do
  use ExUnit.Case
  use Placebo

  alias SmartCity.TestDataGenerator, as: TDG

  @moduletag capture_log: true

  setup do
    TestHelper.start_horde()
    {:ok, scheduler} = Reaper.Scheduler.start_link()
    allow Reaper.DataExtract.Processor.process(any(), any()), exec: fn _ingestion -> Process.sleep(10 * 60_000) end
    ingestion = TDG.create_ingestion(%{id: "ds-to-kill"})

    on_exit(fn ->
      TestHelper.assert_down(scheduler)
    end)

    [ingestion: ingestion]
  end

  describe("currently_running_jobs/0") do
    test "should return all jobs" do
      ingest_1 = TDG.create_ingestion(%{id: "ds-to-kill-1"})
      ingest_2 = TDG.create_ingestion(%{id: "ds-to-kill-2"})
      Reaper.Horde.Supervisor.start_data_extract(ingest_1)
      Reaper.Horde.Supervisor.start_data_extract(ingest_2)

      result = Reaper.currently_running_jobs()

      assert [ingest_1.id, ingest_2.id] == result |> Enum.sort()
    end
  end
end
