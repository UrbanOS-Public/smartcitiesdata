defmodule Reaper.Event.Handlers.IngestionUpdateTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :reaper

  import Checkov
  import ExUnit.CaptureLog

  alias Reaper.Event.Handlers.IngestionUpdate
  alias SmartCity.TestDataGenerator, as: TDG
  alias Quantum.Job
  alias Reaper.Collections.Extractions
  import Crontab.CronExpression

  @instance_name Reaper.instance_name()

  getter(:brook, generic: true)

  setup do
    {:ok, brook} = Brook.start_link(brook() |> Keyword.put(:instance, @instance_name))
    {:ok, scheduler} = Reaper.Scheduler.start_link()

    on_exit(fn ->
      TestHelper.assert_down(scheduler)
      TestHelper.assert_down(brook)
    end)

    Brook.Test.register(@instance_name)

    :ok
  end

  describe "handle/1" do
    test "sends data_extract_start() event for all source types when cadence is once" do
      ingestion = TDG.create_ingestion(%{cadence: "once"})

      assert :ok == IngestionUpdate.handle(ingestion)

      assert_receive {:brook_event, %Brook.Event{type: "data:extract:start", data: ingestion}}
    end

    test "should stop running jobs when cadence is once" do
      ingestion = TDG.create_ingestion(%{cadence: "once"})
      create_job(ingestion.id)

      assert :ok == IngestionUpdate.handle(ingestion)

      assert_receive {:brook_event, %Brook.Event{type: "data:extract:start", data: ^ingestion}}
      assert 0 == Reaper.Scheduler.jobs() |> length()
    end

    test "does not send data_extract_start() event when cadence is once and ingestion has already been fetched" do
      ingestion = TDG.create_ingestion(%{cadence: "once"})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_last_fetched_timestamp(ingestion.id)
      end)

      assert :ok == IngestionUpdate.handle(ingestion)

      refute_receive {:brook_event, %Brook.Event{type: "data:extract:start", data: ingestion}}
    end

    test "adds job to quantum when cadence is a cron expression" do
      ingestion = TDG.create_ingestion(%{id: "ds2", cadence: "* * * * *"})

      assert :ok == IngestionUpdate.handle(ingestion)

      job = Reaper.Scheduler.find_job(:ds2)
      {:ok, expected_ingestion} = Brook.Serializer.serialize(ingestion)
      assert job.schedule == ~e[* * * * *]
      assert job.task == {IngestionUpdate, :protected_event_send, [expected_ingestion]}
    end

    test "jobs that are added to quantum when cadence is a cron expression work, even with missing optional fields" do
      # gotta go fast
      {:ok, cadence} = Crontab.CronExpression.Parser.parse("*/5 * * * * * *", true)
      ingestion = TDG.create_ingestion(%{topLevelSelector: "remove me"})
      ingestion_that_is_missing_top_level_selector = pop_in(ingestion, [:topLevelSelector]) |> elem(1)
      {:ok, serialized_ingestion} = Brook.Serializer.serialize(ingestion_that_is_missing_top_level_selector)

      Reaper.Scheduler.new_job()
      |> Job.set_name(:do_it)
      |> Job.set_schedule(cadence)
      |> Job.set_task({IngestionUpdate, :protected_event_send, [serialized_ingestion]})
      |> Reaper.Scheduler.add_job()

      assert_receive {:brook_event,
                      %Brook.Event{type: "data:extract:start", data: %SmartCity.Ingestion{topLevelSelector: _}}},
                     10_000
    end

    data_test "adds job to quantum with schedule of #{schedule} when cadence is #{cadence}" do
      ingestion = TDG.create_ingestion(%{id: "ds9", cadence: cadence})

      assert :ok == IngestionUpdate.handle(ingestion)

      extended = length(String.split(schedule)) > 5
      {:ok, expected_cron_expression} = Crontab.CronExpression.Parser.parse(schedule, extended)

      job = Reaper.Scheduler.find_job(:ds9)
      assert job.schedule == expected_cron_expression

      where([
        [:cadence, :schedule],
        [86_400_000, "0 6 * * *"],
        [3_600_000, "0 * * * *"],
        [30_000, "*/30 * * * * * *"],
        [10_000, "*/10 * * * * * *"]
      ])
    end

    test "logs message when crontab is unable to be parsed" do
      ingestion = TDG.create_ingestion(%{cadence: "once per minute"})

      {:error, reason} = Crontab.CronExpression.Parser.parse(ingestion.cadence)

      assert capture_log([level: :warn], fn ->
               :ok = IngestionUpdate.handle(ingestion)
             end) =~
               "event(ingestion:update) unable to parse cadence(once per minute) as cron expression, error reason: #{
                 inspect(reason)
               }"
    end

    test "discards ingestion event when cadence is never" do
      ingestion = TDG.create_ingestion(%{cadence: "never"})

      assert capture_log(fn ->
               assert :ok == IngestionUpdate.handle(ingestion)
             end) == ""
    end

    test "deletes quantum job when ingestion cadence is never" do
      ingestion = TDG.create_ingestion(%{cadence: "never"})
      ingestion_id = ingestion.id |> String.to_atom()

      create_job(ingestion.id)

      assert nil != Reaper.Scheduler.find_job(ingestion_id)

      assert :ok == IngestionUpdate.handle(ingestion)

      assert nil == Reaper.Scheduler.find_job(ingestion_id)
    end

    test "updates view state and sets flag to false" do
      ingestion = TDG.create_ingestion(%{cadence: "never"})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_ingestion(ingestion)
        :ok = IngestionUpdate.handle(ingestion)
      end)

      assert false == Extractions.is_enabled?(ingestion.id)
    end
  end

  defp create_job(dataset_id) do
    id = dataset_id |> String.to_atom()

    Reaper.Scheduler.new_job()
    |> Job.set_name(id)
    |> Job.set_schedule(Crontab.CronExpression.Parser.parse!("* * * * *"))
    |> Job.set_task(fn -> IO.puts("Test Job is running") end)
    |> Reaper.Scheduler.add_job()
  end
end
