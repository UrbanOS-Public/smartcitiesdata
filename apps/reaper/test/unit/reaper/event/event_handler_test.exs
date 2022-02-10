defmodule Reaper.Event.EventHandlerTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :reaper

  require Logger

  import SmartCity.Event,
    only: [
      data_extract_end: 0,
      data_extract_start: 0,
      file_ingest_start: 0,
      file_ingest_end: 0,
      dataset_update: 0,
      dataset_disable: 0,
      dataset_delete: 0,
      error_dataset_update: 0
    ]

  import SmartCity.TestHelper, only: [eventually: 1]
  alias Reaper.Collections.FileIngestions
  alias SmartCity.TestDataGenerator, as: TDG

  @instance_name Reaper.instance_name()

  getter(:brook, generic: true)

  setup do
    {:ok, brook} = Brook.start_link(brook() |> Keyword.put(:instance, @instance_name))
    {:ok, horde_supervisor} = Horde.DynamicSupervisor.start_link(name: Reaper.Horde.Supervisor, strategy: :one_for_one)
    {:ok, reaper_horde_registry} = Reaper.Horde.Registry.start_link(name: Reaper.Horde.Registry, keys: :unique)
    allow(TelemetryEvent.add_event_metrics(any(), [:events_handled]), return: :ok)
    Brook.Test.register(@instance_name)

    on_exit(fn ->
      kill(brook)
      kill(horde_supervisor)
      kill(reaper_horde_registry)
    end)

    :ok
  end

  describe "#{dataset_update()}" do
    test "sends error event for known bad case of nil cadence" do
      allow(Reaper.Scheduler.find_job(any()), return: nil)
      dataset = TDG.create_dataset(id: "ds-empty-cron", technical: %{cadence: nil, sourceType: "ingest"})

      assert :ok == Brook.Test.send(@instance_name, dataset_update(), "testing", dataset)

      assert_receive {:brook_event,
                      %Brook.Event{
                        type: error_dataset_update(),
                        data: %{"reason" => _, "dataset" => %SmartCity.Dataset{id: "ds-empty-cron"}}
                      }},
                     10_000
    end

    test "sends error event for raised errors while performing dataset update" do
      allow(Reaper.Event.Handlers.DatasetUpdate.handle(any()), exec: fn _ -> raise "bad stuff" end)

      dataset = TDG.create_dataset(%{})

      assert :ok == Brook.Test.send(@instance_name, dataset_update(), "testing", dataset)

      assert_receive {:brook_event,
                      %Brook.Event{
                        type: "error:dataset:update",
                        data: %{"reason" => %RuntimeError{message: "bad stuff"}, "dataset" => _}
                      }},
                     10_000
    end
  end

  describe "#{data_extract_start()}" do
    setup do
      date = DateTime.utc_now()
      allow DateTime.utc_now(), return: date, meck_options: [:passthrough]
      dataset = TDG.create_dataset(id: "ds2", technical: %{sourceType: "ingest"})

      [dataset: dataset, date: date]
    end

    test "should ask horde to start process with appropriate name", %{dataset: dataset} do
      test_pid = self()

      Brook.Test.with_event(@instance_name, fn -> Reaper.Collections.Extractions.update_dataset(dataset) end)

      allow Reaper.DataExtract.Processor.process(any()),
        exec: fn processor_dataset ->
          [{_pid, _}] = Horde.Registry.lookup(Reaper.Horde.Registry, dataset.id)
          send(test_pid, {:registry, processor_dataset})
        end

      Brook.Test.send(@instance_name, data_extract_start(), "testing", dataset)

      assert_receive {:registry, ^dataset}
    end

    test "should persist the dataset and start time in the view state", %{dataset: dataset, date: date} do
      allow Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid}
      Brook.Test.with_event(@instance_name, fn -> Reaper.Collections.Extractions.update_dataset(dataset) end)
      Brook.Test.send(@instance_name, data_extract_start(), "testing", dataset)

      eventually(fn ->
        extraction = Brook.get!(@instance_name, :extractions, dataset.id)
        assert extraction != nil
        assert dataset == Map.get(extraction, "dataset")
        assert date == Map.get(extraction, "started_timestamp")
      end)
    end

    test "should send ingest_start event", %{dataset: dataset} do
      allow Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid}
      Brook.Test.with_event(@instance_name, fn -> Reaper.Collections.Extractions.update_dataset(dataset) end)
      Brook.Test.send(@instance_name, data_extract_start(), :reaper, dataset)

      assert_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: dataset}}
    end

    test "should send ingest_start event for streaming data on the first event" do
      allow Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid}
      dataset = TDG.create_dataset(id: "ds2", technical: %{sourceType: "stream"})
      Brook.Test.with_event(@instance_name, fn -> Reaper.Collections.Extractions.update_dataset(dataset) end)
      Brook.Test.send(@instance_name, data_extract_start(), :reaper, dataset)

      assert_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: dataset}}
    end

    test "should not send ingest_start event for streaming data on subsequent events" do
      allow Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid}
      dataset = TDG.create_dataset(id: "ds2", technical: %{sourceType: "stream"})
      Brook.Test.with_event(@instance_name, fn -> Reaper.Collections.Extractions.update_dataset(dataset) end)
      Brook.Test.send(@instance_name, data_extract_start(), :reaper, dataset)
      Brook.Test.send(@instance_name, data_extract_end(), :reaper, dataset)

      assert_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: ^dataset}}

      Brook.Test.send(@instance_name, data_extract_start(), :reaper, dataset)
      refute_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: ^dataset}}, 1_000
    end

    test "should send #{data_extract_end()} when processor is completed" do
      allow Reaper.DataExtract.Processor.process(any()), return: :ok
      dataset = TDG.create_dataset(id: "ds3", technical: %{sourceType: "ingest"})
      Brook.Test.with_event(@instance_name, fn -> Reaper.Collections.Extractions.update_dataset(dataset) end)
      Brook.Test.send(@instance_name, data_extract_start(), :reaper, dataset)

      assert_receive {:brook_event, %Brook.Event{type: data_extract_end(), data: dataset}}
    end
  end

  describe "#{data_extract_end()}" do
    test "should persist last fetched timestamp" do
      date = DateTime.utc_now()
      allow DateTime.utc_now(), return: date, meck_options: [:passthrough]
      dataset = TDG.create_dataset(id: "ds1")
      Brook.Test.send(@instance_name, data_extract_end(), "testing", dataset)

      eventually(fn ->
        extraction = Brook.get!(@instance_name, :extractions, dataset.id)
        assert extraction != nil
        assert date == Map.get(extraction, "last_fetched_timestamp", nil)
      end)
    end
  end

  describe "#{dataset_delete()}" do
    test "should stop and delete the dataset if it is a successful stop" do
      allow Reaper.Event.Handlers.DatasetDelete.handle(any()), return: :result_not_relevant
      allow Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid}

      dataset = TDG.create_dataset(id: Faker.UUID.v4())
      Brook.Test.send(@instance_name, data_extract_start(), :author, dataset)
      Brook.Test.send(@instance_name, dataset_delete(), :author, dataset)

      eventually(fn ->
        assert nil == Brook.get!(@instance_name, :extractions, dataset.id)
        assert_called Reaper.Event.Handlers.DatasetDelete.handle(dataset)
      end)
    end
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
