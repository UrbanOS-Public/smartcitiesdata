defmodule Reaper.Event.Handlers.IngestionDeleteTest do
  use ExUnit.Case
  import Mox
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

  setup :verify_on_exit!
  
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

      expect(StopIngestionMock, :delete_quantum_job, fn id when id == ingestion.id -> :ok end)
      expect(StopIngestionMock, :stop_horde_and_cache, fn id when id == ingestion.id -> :ok end)
      expect(TopicManagerMock, :delete_topic, fn id when id == ingestion.id -> :ok end)

      assert :ok == IngestionDelete.handle(ingestion)
    end

    test "delete successfully handles errors" do
      ingestion = TDG.create_ingestion(%{cadence: "once"})

      expect(StopIngestionMock, :delete_quantum_job, fn id when id == ingestion.id -> :error end)
      # Note: The other mocks won't be called because the with statement fails on the first :error

      assert capture_log([level: :error], fn ->
               :ok = IngestionDelete.handle(ingestion)
             end) =~
               "Elixir.Reaper.Event.Handlers.IngestionDelete: Error occurred while deleting the ingestion: #{ingestion.id}, Reason: :error"
    end
  end
end
