defmodule Reaper.MigrationsTest do
  use ExUnit.Case
  use Divo, auto_start: false
  use Properties, otp_app: :reaper

  import SmartCity.TestHelper
  alias SmartCity.TestDataGenerator, as: TDG

  @instance_name Reaper.instance_name()

  getter(:brook, generic: true)

  describe "quantum job migration" do
    @tag :capture_log
    test "should pre-pend the brook instance to all scheduled quantum jobs" do
      Application.ensure_all_started(:redix)

      {:ok, redix} = Redix.start_link(Keyword.put(Application.get_env(:redix, :args, []), :name, :redix))
      {:ok, scheduler} = Reaper.Scheduler.Supervisor.start_link([])
      Process.unlink(redix)
      Process.unlink(scheduler)

      ingestion_id = String.to_atom("old-cron-schedule")
      create_job(ingestion_id)

      kill(scheduler)
      kill(redix)

      Application.ensure_all_started(:reaper)

      Process.sleep(10_000)

      eventually(fn ->
        job = Reaper.Scheduler.find_job(ingestion_id)
        assert job.task == {Brook.Event, :send, [@instance_name, "migration:test", :reaper, ingestion_id]}
      end)

      Application.stop(:reaper)
    end
  end

  defp create_job(ingestion_id) do
    Reaper.Scheduler.new_job()
    |> Quantum.Job.set_name(ingestion_id)
    |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!("* * * * *"))
    |> Quantum.Job.set_task({Brook.Event, :send, ["migration:test", :reaper, ingestion_id]})
    |> Reaper.Scheduler.add_job()
  end

  describe "extractions migration" do
    @tag :capture_log
    test "should migrate extractions and enable all of them" do
      Application.ensure_all_started(:redix)
      Application.ensure_all_started(:faker)

      {:ok, redix} = Redix.start_link(Keyword.put(Application.get_env(:redix, :args, []), :name, :redix))
      Process.unlink(redix)

      {:ok, brook} =
        Brook.start_link(
          brook()
          |> Keyword.delete(:driver)
          |> Keyword.put(:instance, @instance_name)
        )

      Process.unlink(brook)

      extraction_without_enabled_flag_id = 1
      extraction_with_enabled_true_id = 2
      extraction_with_enabled_false_id = 3
      invalid_extraction_id = 4

      Brook.Test.with_event(
        @instance_name,
        Brook.Event.new(type: "reaper_config:migration", author: "migration", data: %{}),
        fn ->
          Brook.ViewState.merge(:extractions, extraction_without_enabled_flag_id, %{
            ingestion: TDG.create_ingestion(id: extraction_without_enabled_flag_id)
          })

          Brook.ViewState.merge(:extractions, extraction_with_enabled_true_id, %{
            ingestion: TDG.create_ingestion(id: extraction_with_enabled_true_id),
            enabled: true
          })

          Brook.ViewState.merge(:extractions, extraction_with_enabled_false_id, %{
            ingestion: TDG.create_ingestion(id: extraction_with_enabled_false_id),
            enabled: false
          })

          Brook.ViewState.merge(:extractions, invalid_extraction_id, %{})
        end
      )

      kill(brook)
      kill(redix)

      Application.ensure_all_started(:reaper)

      Process.sleep(10_000)

      eventually(fn ->
        assert true == Brook.get!(@instance_name, :extractions, extraction_without_enabled_flag_id)["enabled"]
        assert true == Brook.get!(@instance_name, :extractions, extraction_with_enabled_true_id)["enabled"]
        assert false == Brook.get!(@instance_name, :extractions, extraction_with_enabled_false_id)["enabled"]
      end)

      Application.stop(:reaper)
    end
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)
    assert_receive {:DOWN, ^ref, _, _, _}, 5_000
  end
end
