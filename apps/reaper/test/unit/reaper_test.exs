defmodule ReaperTests do
  use ExUnit.Case
  use Placebo

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

  describe("currently_running_jobs/0") do
    test "should return all jobs" do
      dataset_1 = TDG.create_dataset(id: "ds-to-kill-1")
      dataset_2 = TDG.create_dataset(id: "ds-to-kill-2")
      Reaper.Horde.Supervisor.start_data_extract(dataset_1)
      Reaper.Horde.Supervisor.start_data_extract(dataset_2)

      result = Reaper.currently_running_jobs()

      assert [dataset_1.id, dataset_2.id] == result |> Enum.sort()
    end
  end

	describe("filtering empty redis args") do
		test "redis_args should return no password when empty string" do
			Application.put_env(:redix, :args, [host: "host", password: ""])

			result = Reaper.redis_args()

			assert result == [host: "host"]
		end

		test "reaper quantum storage should return no password when empty string" do
			Application.put_env(:reaper, Reaper.Quantum.Storage, [host: "host", password: ""])

			result = Reaper.redis_quantum_storage()

			assert result == [host: "host"]
		end
	end
end
