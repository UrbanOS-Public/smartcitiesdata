defmodule Reaper.MigrationsTest do
  use ExUnit.Case
  use Divo, auto_start: false

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [dataset_update: 0]
  alias Reaper.ReaperConfig
  alias Reaper.Persistence
  alias Reaper.Collections.Extractions
  alias Reaper.Collections.FileIngestions
  import SmartCity.TestHelper

  @tag :capture_log
  test "should migrate reaper_config and last_fetched_timestamp to brook view state" do
    Application.ensure_all_started(:redix)
    Application.ensure_all_started(:faker)

    {:ok, redix} = Redix.start_link(host: Application.get_env(:redix, :host), name: :redix)
    Process.unlink(redix)
    {:ok, brook} = Brook.start_link(Application.get_env(:reaper, :brook) |> Keyword.delete(:driver))
    Process.unlink(brook)

    ingest_date = DateTime.utc_now()
    ingest_dataset = TDG.create_dataset(id: "ds-2-migrate", technical: %{sourceType: "ingest"})
    setup_old_env(ingest_dataset, ingest_date)

    hosted_date = DateTime.utc_now()
    hosted_dataset = TDG.create_dataset(id: "host-2-migrate", technical: %{sourceType: "host"})
    setup_old_env(hosted_dataset, hosted_date)

    kill(brook)
    kill(redix)

    Application.ensure_all_started(:reaper)

    Process.sleep(10_000)

    eventually(fn ->
      assert ingest_dataset == Extractions.get_dataset!(ingest_dataset.id)
      assert ingest_date == Extractions.get_last_fetched_timestamp!(ingest_dataset.id)
      assert ingest_dataset.id not in (Extractions.get_all_non_completed!() |> Enum.map(fn x -> x.dataset.id end))
    end)

    eventually(fn ->
      assert hosted_dataset = FileIngestions.get_dataset!(hosted_dataset.id)
      assert hosted_date = FileIngestions.get_last_fetched_timestamp!(hosted_dataset.id)
      assert hosted_dataset.id not in (FileIngestions.get_all_non_completed!() |> Enum.map(fn x -> x.dataset.id end))
    end)

    Application.stop(:reaper)
  end

  defp setup_old_env(dataset, date) do
    {:ok, reaper_config} = ReaperConfig.from_dataset(dataset)
    event = %Brook.Event{type: dataset_update(), author: "reaper", data: dataset}
    Brook.Test.save_view_state(event, :reaper_config, dataset.id, reaper_config)
    Persistence.record_last_fetched_timestamp(dataset.id, date)
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)
    assert_receive {:DOWN, ^ref, _, _, _}, 5_000
  end
end
