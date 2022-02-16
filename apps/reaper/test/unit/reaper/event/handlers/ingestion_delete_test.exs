defmodule Reaper.Event.Handlers.IngestionDeleteTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :reaper

  import Checkov
  import ExUnit.CaptureLog

  alias Reaper.Event.Handlers.IngestionDelete
  alias Reaper.Event.Handlers.Helper.StopIngestion
  alias Reaper.Topic.TopicManager
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
    test "successfully deletes ingestion" do
      ingestion = TDG.create_ingestion(%{cadence: "once"})

      allow StopIngestion.delete_quantum_job(ingestion.id), return: :ok
      allow StopIngestion.stop_horde_and_cache(ingestion.id), return: :ok
      allow TopicManager.delete_topic(ingestion.id), return: :ok

      assert :ok == IngestionDelete.handle(ingestion)

      assert_called StopIngestion.delete_quantum_job(ingestion.id)
      assert_called StopIngestion.stop_horde_and_cache(ingestion.id)
      assert_called TopicManager.delete_topic(ingestion.id)
    end

    test "delete successfully handles errors" do
      ingestion = TDG.create_ingestion(%{cadence: "once"})

      allow StopIngestion.delete_quantum_job(ingestion.id), return: :error
      allow StopIngestion.stop_horde_and_cache(ingestion.id), return: :error
      allow TopicManager.delete_topic(ingestion.id), return: :error

      assert capture_log([level: :error], fn ->
               :ok = IngestionDelete.handle(ingestion)
             end) =~
               "Elixir.Reaper.Event.Handlers.IngestionDelete: Error occurred while deleting the ingestion: #{
                 ingestion.id
               }, Reason: :error"
    end
  end
end
