defmodule Reaper.Event.HandlerTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.Event, only: [dataset_extract_complete: 0, dataset_extract_start: 0]
  import SmartCity.TestHelper, only: [eventually: 1]

  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    {:ok, brook} = Brook.start_link(Application.get_env(:reaper, :brook))
    {:ok, horde_supervisor} = Horde.Supervisor.start_link([name: Reaper.Horde.Supervisor, strategy: :one_for_one])

    on_exit(fn ->
      kill(brook)
      kill(horde_supervisor)
    end)

    :ok
  end

  describe "#{dataset_extract_start()}" do
    setup do
      date = NaiveDateTime.utc_now()
      allow NaiveDateTime.utc_now(), return: date
      dataset = TDG.create_dataset(id: "ds2", technical: %{sourceType: "ingest"})
      Brook.Event.send(dataset_extract_start(), "testing", dataset)

      [dataset: dataset, date: date]
    end

    test "should ask horde to start process with appropriate id", %{dataset: dataset} do
      eventually(fn ->
        [{id, _, _, _}] = Horde.Supervisor.which_children(Reaper.Horde.Supervisor)
        assert dataset.id == id
      end)
    end

    test "should persist the dataset and start time in the view state", %{dataset: dataset, date: date} do
      eventually(fn ->
        extraction = Brook.get!(:extractions, dataset.id)
        assert extraction != nil
        assert dataset == Map.get(extraction, :dataset)
        assert date == Map.get(extraction, :started_timestamp)
      end)
    end
  end

  describe "#{dataset_extract_complete()}" do
    test "should persist last fetched timestamp" do
      date = NaiveDateTime.utc_now()
      allow NaiveDateTime.utc_now(), return: date, meck_options: [:passthrough]
      dataset = TDG.create_dataset(id: "ds1")
      Brook.Event.send(dataset_extract_complete(), "testing", dataset)

      eventually(fn ->
        extraction = Brook.get!(:extractions, dataset.id)
        assert extraction != nil
        assert date == Map.get(extraction, :last_fetched_timestamp, nil)
      end)
    end
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
