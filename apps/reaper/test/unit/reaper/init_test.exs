defmodule Reaper.InitTest do
  use ExUnit.Case
  use Placebo
  use Properties, otp_app: :reaper

  alias SmartCity.TestDataGenerator, as: TDG
  alias Reaper.Collections.{Extractions}
  import SmartCity.TestHelper

  @instance_name Reaper.instance_name()

  getter(:brook, generic: true)

  setup do
    {:ok, horde_supervisor} = Horde.DynamicSupervisor.start_link(name: Reaper.Horde.Supervisor, strategy: :one_for_one)
    {:ok, reaper_horde_registry} = Reaper.Horde.Registry.start_link(name: Reaper.Horde.Registry, keys: :unique)
    {:ok, brook} = Brook.start_link(brook() |> Keyword.put(:instance, @instance_name))

    on_exit(fn ->
      kill(brook)
      kill(reaper_horde_registry)
      kill(horde_supervisor)
    end)

    Brook.Test.register(@instance_name)

    :ok
  end

  describe "Extractions" do
    test "starts all extract processes that should be running" do
      allow Reaper.DataExtract.Processor.process(any(), any()), return: :ok

      ingestion = TDG.create_ingestion(%{id: "ds1", sourceType: "ingest"})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_ingestion(ingestion)
        Extractions.update_started_timestamp(ingestion.id)
        Extractions.update_last_fetched_timestamp(ingestion.id, nil)
      end)

      Reaper.Init.run()

      eventually(fn ->
        assert_called Reaper.DataExtract.Processor.process(ingestion, any())
      end)
    end

    test "does not start successfully completed extract processes" do
      allow Reaper.DataExtract.Processor.process(any(), any()), return: :ok

      start_time = DateTime.utc_now()
      end_time = start_time |> DateTime.add(3600, :second)

      ingestion = TDG.create_ingestion(%{id: "ds1", sourceType: "ingest"})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_ingestion(ingestion)
        Extractions.update_started_timestamp(ingestion.id, start_time)
        Extractions.update_last_fetched_timestamp(ingestion.id, end_time)
      end)

      Reaper.Init.run()

      refute_called Reaper.DataExtract.Processor.process(ingestion, any())
    end

    test "does not start a ingestion that is disabled" do
      allow Reaper.DataExtract.Processor.process(any(), any()), return: :ok

      start_time = DateTime.utc_now()

      ingestion = TDG.create_ingestion(%{id: "ds1", sourceType: "ingest"})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_ingestion(ingestion)
        Extractions.update_started_timestamp(ingestion.id, start_time)
        Extractions.disable_ingestion(ingestion.id)
      end)

      Reaper.Init.run()

      refute_called Reaper.DataExtract.Processor.process(ingestion, any())
    end

    test "starts data extract process when started_timestamp > last_fetched_timestamp" do
      allow Reaper.DataExtract.Processor.process(any(), any()), return: :ok

      start_time = DateTime.utc_now()
      end_time = start_time |> DateTime.add(-3600, :second)

      ingestion = TDG.create_ingestion(%{id: "ds1", sourceType: "ingest"})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_ingestion(ingestion)
        Extractions.update_started_timestamp(ingestion.id, start_time)
        Extractions.update_last_fetched_timestamp(ingestion.id, end_time)
      end)

      Reaper.Init.run()

      eventually(fn ->
        assert_called Reaper.DataExtract.Processor.process(ingestion, any())
      end)
    end

    test "does not start extract process when started_timestamp was not available" do
      allow Reaper.DataExtract.Processor.process(any(), any()), return: :ok
      dataset = TDG.create_dataset(id: "ds1", technical: %{sourceType: "ingest"})

      Brook.Test.with_event(@instance_name, fn ->
        Extractions.update_last_fetched_timestamp(dataset.id, DateTime.utc_now())
      end)

      Reaper.Init.run()

      refute_called Reaper.DataExtract.Processor.process(dataset, any())
    end
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :normal)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
