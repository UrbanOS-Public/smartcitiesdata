defmodule Reaper.Event.HandlerTest do
  use ExUnit.Case
  use Placebo
  require Logger

  import SmartCity.Event, only: [dataset_extract_complete: 0, dataset_extract_start: 0]

  import SmartCity.TestHelper, only: [eventually: 1]

  alias SmartCity.TestDataGenerator, as: TDG

  setup do
    {:ok, brook} = Brook.start_link(Application.get_env(:reaper, :brook))
    {:ok, horde_supervisor} = Horde.Supervisor.start_link(name: Reaper.Horde.Supervisor, strategy: :one_for_one)
    {:ok, reaper_horde_registry} = Reaper.Horde.Registry.start_link(name: Reaper.Horde.Registry, keys: :unique)

    on_exit(fn ->
      kill(brook)
      kill(horde_supervisor)
      kill(reaper_horde_registry)
    end)

    :ok
  end

  describe "#{dataset_extract_start()}" do
    setup do
      date = NaiveDateTime.utc_now()
      allow NaiveDateTime.utc_now(), return: date
      dataset = TDG.create_dataset(id: "ds2", technical: %{sourceType: "ingest"})

      [dataset: dataset, date: date]
    end

    test "should ask horde to start process with appropriate name", %{dataset: dataset} do
      test_pid = self()

      allow Reaper.DataFeed.process(any(), any()),
        exec: fn arg1, arg2 ->
          [{pid, _}] = Horde.Registry.lookup(Reaper.Horde.Registry, dataset.id)
          send(test_pid, {:registry, arg1})
        end

      Brook.Test.send(dataset_extract_start(), "testing", dataset)

      assert_receive {:registry, ^dataset}
    end

    test "should persist the dataset and start time in the view state", %{dataset: dataset, date: date} do
      Brook.Test.send(dataset_extract_start(), "testing", dataset)

      eventually(fn ->
        extraction = Brook.get!(:extractions, dataset.id)
        assert extraction != nil
        assert dataset == Map.get(extraction, :dataset)
        assert date == Map.get(extraction, :started_timestamp)
      end)
    end

    test "should send ingest_start event", %{dataset: dataset} do
      Brook.Test.send(dataset_extract_start(), :reaper, dataset)

      assert_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: dataset}}
    end

    test "should send ingest_start event for streaming data on the first event" do
      dataset = TDG.create_dataset(id: "ds2", technical: %{sourceType: "stream"})
      Brook.Test.send(dataset_extract_start(), :reaper, dataset)

      assert_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: dataset}}
    end

    test "should not send ingest_start event for streaming data on subsequent events" do
      dataset = TDG.create_dataset(id: "ds2", technical: %{sourceType: "stream"})
      Brook.Test.send(dataset_extract_start(), :reaper, dataset)

      assert_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: dataset}}

      Brook.Test.send(dataset_extract_start(), :reaper, dataset)
      refute_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: dataset}}
    end
  end

  describe "#{dataset_extract_complete()}" do
    test "should persist last fetched timestamp" do
      date = NaiveDateTime.utc_now()
      allow NaiveDateTime.utc_now(), return: date, meck_options: [:passthrough]
      dataset = TDG.create_dataset(id: "ds1")
      Brook.Test.send(dataset_extract_complete(), "testing", dataset)

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
