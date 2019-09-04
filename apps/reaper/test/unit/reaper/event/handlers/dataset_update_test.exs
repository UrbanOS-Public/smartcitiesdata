defmodule Reaper.Event.Handlers.DatasetUpdateTest do
  use ExUnit.Case
  use Placebo
  import Checkov
  import ExUnit.CaptureLog

  alias Reaper.Event.Handlers.DatasetUpdate
  alias SmartCity.TestDataGenerator, as: TDG
  alias Quantum.Job
  import Crontab.CronExpression

  describe "handle/1" do
    data_test "sends #{event} for source type #{source_type} event when cadence is once" do
      allow Brook.get!(:extractions, any()), return: nil
      allow Brook.Event.send(any(), any(), any()), return: :ok
      dataset = TDG.create_dataset(id: "ds1", technical: %{cadence: "once", sourceType: source_type})

      assert :ok == DatasetUpdate.handle(dataset)

      assert_called Brook.Event.send(event, any(), dataset)

      where([
        [:source_type, :event],
        ["ingest", "dataset:extract:start"],
        ["host", "hosted:file:start"]
      ])
    end

    data_test "does not send #{event} for source type #{source_type} when cadence is once and dataset has already been fetched" do
      allow Brook.get!(:extractions, any()), return: %{last_fetched_timestamp: :last_fetched_timestamp}
      allow Brook.Event.send(any(), any(), any()), return: :ok
      dataset = TDG.create_dataset(id: "ds1", technical: %{cadence: "once", sourceType: source_type})

      assert :ok == DatasetUpdate.handle(dataset)

      refute_called Brook.Event.send(event, any(), dataset)

      where([
        [:source_type, :event],
        ["ingest", "dataset:extract:start"],
        ["host", "hosted:file:start"]
      ])
    end

    data_test "adds job to quantum when cadence is a cron expression" do
      allow Reaper.Scheduler.add_job(any()), return: :ok, meck_options: [:passthrough]
      allow Reaper.Scheduler.delete_job(any()), return: :ok, meck_options: [:passthrough]
      dataset = TDG.create_dataset(id: "ds2", technical: %{cadence: "* * * * *", sourceType: source_type})

      assert :ok == DatasetUpdate.handle(dataset)

      job =
        Reaper.Scheduler.new_job()
        |> Job.set_name(:ds2)
        |> Job.set_schedule(~e[* * * * *])
        |> Job.set_task({Brook.Event, :send, [event, :reaper, dataset]})

      assert_called Reaper.Scheduler.delete_job(:ds2)
      assert_called Reaper.Scheduler.add_job(job)

      where([
        [:source_type, :event],
        ["ingest", "dataset:extract:start"],
        ["host", "hosted:file:start"]
      ])
    end

    test "logs message when crontab is unable to be parsed" do
      allow Reaper.Scheduler.add_job(any()), return: :ok, meck_options: [:passthrough]
      dataset = TDG.create_dataset(id: "ds2", technical: %{cadence: "once per minute", sourceType: "ingest"})

      {:error, reason} = Crontab.CronExpression.Parser.parse(dataset.technical.cadence)

      assert capture_log([level: :warn], fn ->
               :ok = DatasetUpdate.handle(dataset)
             end) =~
               "event(dataset:update) unable to parse cadence(once per minute) as cron expression, error reason: #{
                 inspect(reason)
               }"
    end

    test "discards event when cadence is never" do
      dataset = TDG.create_dataset(id: "ds3", technical: %{cadence: "never", sourceType: "ingest"})

      assert capture_log(fn ->
               assert :ok == DatasetUpdate.handle(dataset)
             end) == ""
    end
  end
end
