defmodule Reaper.Event.EventHandlerTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :reaper

  require Logger

  import SmartCity.Event,
    only: [
      data_ingest_start: 0,
      data_extract_start: 0,
      data_extract_end: 0,
      dataset_delete: 0,
      ingestion_update: 0,
      ingestion_delete: 0,
      error_ingestion_update: 0
    ]

  import SmartCity.TestHelper, only: [eventually: 1]
  alias SmartCity.TestDataGenerator, as: TDG
  alias Reaper.Event.Handlers.IngestionDelete

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

  describe "#{ingestion_update()}" do
    test "sends error event for known bad case of nil cadence" do
      allow(Reaper.Scheduler.find_job(any()), return: nil)
      ingestion = TDG.create_ingestion(%{id: "ds-empty-cron", cadence: nil})

      assert :ok == Brook.Test.send(@instance_name, ingestion_update(), "testing", ingestion)

      assert_receive {:brook_event,
                      %Brook.Event{
                        type: error_ingestion_update(),
                        data: %{
                          "reason" => _,
                          "ingestion" => %SmartCity.Ingestion{id: "ds-empty-cron"}
                        }
                      }},
                     10_000
    end

    test "sends error event for raised errors while performing ingestion update" do
      allow(Reaper.Event.Handlers.IngestionUpdate.handle(any()),
        exec: fn _ -> raise "bad stuff" end
      )

      ingestion = TDG.create_ingestion(%{})

      assert :ok == Brook.Test.send(@instance_name, ingestion_update(), "testing", ingestion)

      assert_receive {:brook_event,
                      %Brook.Event{
                        type: "error:ingestion:update",
                        data: %{"reason" => %RuntimeError{message: "bad stuff"}, "ingestion" => _}
                      }},
                     10_000
    end
  end

  describe "#{data_extract_start()}" do
    setup do
      date = DateTime.utc_now()
      allow(DateTime.utc_now(), return: date, meck_options: [:passthrough])
      ingestion = TDG.create_ingestion(%{id: "ds2"})

      [ingestion: ingestion, date: date]
    end

    test "should ask horde to start process with appropriate name", %{ingestion: ingestion} do
      test_pid = self()

      Brook.Test.with_event(@instance_name, fn ->
        Reaper.Collections.Extractions.update_ingestion(ingestion)
      end)

      allow(Reaper.DataExtract.Processor.process(any(), any()),
        exec: fn processor_ingestion, timestamp ->
          [{_pid, _}] = Horde.Registry.lookup(Reaper.Horde.Registry, ingestion.id)
          send(test_pid, {:registry, processor_ingestion})
        end
      )

      Brook.Test.send(@instance_name, data_extract_start(), "testing", ingestion)

      assert_receive {:registry, ^ingestion}
    end

    test "should persist the ingestion and start time in the view state", %{
      ingestion: ingestion,
      date: date
    } do
      allow(Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid})

      Brook.Test.with_event(@instance_name, fn ->
        Reaper.Collections.Extractions.update_ingestion(ingestion)
      end)

      Brook.Test.send(@instance_name, data_extract_start(), "testing", ingestion)

      eventually(fn ->
        extraction = Brook.get!(@instance_name, :extractions, ingestion.id)
        assert extraction != nil
        assert ingestion == Map.get(extraction, "ingestion")
        assert date == Map.get(extraction, "started_timestamp")
      end)
    end

    test "should send ingest_start event", %{ingestion: ingestion} do
      allow(Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid})

      Brook.Test.with_event(@instance_name, fn ->
        Reaper.Collections.Extractions.update_ingestion(ingestion)
      end)

      Brook.Test.send(@instance_name, data_extract_start(), :reaper, ingestion)

      assert_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: ingestion}}
    end

    test "should send ingest_start event for streaming data on the first event" do
      allow(Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid})
      ingestion = TDG.create_ingestion(%{id: "ds2", cadence: "1 2 24 * * *"})

      Brook.Test.with_event(@instance_name, fn ->
        Reaper.Collections.Extractions.update_ingestion(ingestion)
      end)

      Brook.Test.send(@instance_name, data_extract_start(), :reaper, ingestion)

      assert_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: ingestion}}
    end

    test "should not send ingest_start event for data that updates more than once per minute on subsequent events" do
      allow(Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid})

      ingestion = TDG.create_ingestion(%{id: "in1", targetDataset: "ds2", cadence: "* 2 24 * * *"})

      Brook.Test.with_event(@instance_name, fn ->
        Reaper.Collections.Extractions.update_ingestion(ingestion)
      end)

      Brook.Test.send(@instance_name, data_extract_start(), :reaper, ingestion)
      send_data_extract_end(ingestion.id, ingestion.targetDataset, 0, Timex.to_unix(Timex.now()))

      assert_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: ^ingestion}}

      Brook.Test.send(@instance_name, data_extract_start(), :reaper, ingestion)

      refute_receive {:brook_event, %Brook.Event{type: "data:ingest:start", data: ^ingestion}},
                     1_000
    end

    test "should send #{data_extract_end()} when processor is completed" do
      allow(Reaper.DataExtract.Processor.process(any(), any()), return: :ok)
      ingestion = TDG.create_ingestion(%{id: "ds3"})

      Brook.Test.with_event(@instance_name, fn ->
        Reaper.Collections.Extractions.update_ingestion(ingestion)
      end)

      Brook.Test.send(@instance_name, data_extract_start(), :reaper, ingestion)

      assert_receive {:brook_event, %Brook.Event{type: data_extract_end(), data: ingestion}}
    end
  end

  describe "#{data_extract_end()}" do
    test "should persist last fetched timestamp" do
      date = DateTime.utc_now()
      allow(DateTime.utc_now(), return: date, meck_options: [:passthrough])
      ingestion = TDG.create_ingestion(%{id: "ing1", targetDataset: "ds1"})
      send_data_extract_end(ingestion.id, ingestion.targetDataset, 0, Timex.to_unix(date))

      eventually(fn ->
        extraction = Brook.get!(@instance_name, :extractions, ingestion.id)
        assert extraction != nil
        assert date == Map.get(extraction, "last_fetched_timestamp", nil)
      end)
    end
  end

  describe "#{dataset_delete()}" do
    @tag focus: true
    test "should delete associated raw topic when dataset:delete event fires" do
      dataset = TDG.create_dataset(id: "dataset_id", technical: %{sourceType: "ingest"})

      non_matching_ingestion = TDG.create_ingestion(%{id: 1, targetDataset: "other_dataset"})
      matching_ingestion = TDG.create_ingestion(%{id: 2, targetDataset: "dataset_id"})
      another_matching_ingestion = TDG.create_ingestion(%{id: 3, targetDataset: "dataset_id"})

      mock_view_state = %{
        1 => %{
          "ingestion" => non_matching_ingestion
        },
        2 => %{
          "ingestion" => matching_ingestion
        },
        3 => %{
          "ingestion" => another_matching_ingestion
        }
      }

      allow(IngestionDelete.handle(any()), return: :ok)
      allow(Brook.ViewState.get_all(@instance_name, :extractions), return: {:ok, mock_view_state})

      Brook.Test.send(@instance_name, dataset_delete(), :reaper, dataset)

      assert_called(IngestionDelete.handle(matching_ingestion))
      assert_called(IngestionDelete.handle(another_matching_ingestion))
      refute_called(IngestionDelete.handle(non_matching_ingestion))
    end
  end

  describe "#{ingestion_delete()}" do
    test "successfully deletes an ingestion when event is sent" do
      ingestion = TDG.create_ingestion(%{id: "ds9"})

      allow(Reaper.Event.Handlers.IngestionDelete.handle(any()), return: :result_not_relevant)
      allow(Horde.DynamicSupervisor.start_child(any(), any()), return: {:ok, :pid})

      Brook.Test.send(@instance_name, data_extract_start(), :author, ingestion)
      Brook.Test.send(@instance_name, ingestion_delete(), :author, ingestion)

      eventually(fn ->
        assert nil == Brook.get!(@instance_name, :extractions, ingestion.id)
        assert_called(Reaper.Event.Handlers.IngestionDelete.handle(ingestion))
      end)
    end

    test "sends error event for raised errors while performing ingestion update" do
      allow(Reaper.Event.Handlers.IngestionUpdate.handle(any()),
        exec: fn _ -> raise "bad stuff" end
      )

      ingestion = TDG.create_ingestion(%{})

      assert :ok == Brook.Test.send(@instance_name, ingestion_update(), "testing", ingestion)

      assert_receive {:brook_event,
                      %Brook.Event{
                        type: "error:ingestion:update",
                        data: %{"reason" => %RuntimeError{message: "bad stuff"}, "ingestion" => _}
                      }},
                     10_000
    end
  end

  defp send_data_extract_end(ingestion_id, dataset_id, msgs_count, unix_time) do
    msg = %{
      ingestion_id: ingestion_id,
      dataset_id: dataset_id,
      msgs_extracted: msgs_count,
      extract_start_unix: unix_time
    }

    Brook.Test.send(@instance_name, data_extract_end(), "testing", msg)
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
