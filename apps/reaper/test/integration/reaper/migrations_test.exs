defmodule Reaper.MigrationsTest do
  use ExUnit.Case
  use Divo, auto_start: false

  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [dataset_update: 0]
  alias Reaper.ReaperConfig
  alias Reaper.Persistence
  alias Reaper.Collections.Extractions
  import SmartCity.TestHelper

  test "should migrate reaper_config and last_fetched_timestamp to brook view state extractions" do
    Application.ensure_all_started(:redix)
    Application.ensure_all_started(:faker)

    {:ok, redix} = Redix.start_link(host: Application.get_env(:redix, :host), name: :redix)
    Process.unlink(redix)
    {:ok, brook} = Brook.start_link(Application.get_env(:reaper, :brook) |> Keyword.delete(:driver))
    Process.unlink(brook)

    date = DateTime.utc_now()
    dataset = TDG.create_dataset(id: "ds-2-migrate", technical: %{sourceType: "ingest"})
    {:ok, reaper_config} = ReaperConfig.from_dataset(dataset)
    event = %Brook.Event{type: dataset_update(), author: "reaper", data: dataset}
    Brook.Test.save_view_state(event, :reaper_config, dataset.id, reaper_config)
    Persistence.record_last_fetched_timestamp(dataset.id, date)

    kill(brook)
    kill(redix)

    Application.ensure_all_started(:reaper)

    Process.sleep(5_000)

    eventually(fn ->
      assert dataset == Extractions.get_dataset!(dataset.id)
      assert date == Extractions.get_last_fetched_timestamp!(dataset.id)
      assert dataset.id not in (Extractions.get_all_non_completed!() |> Enum.map(fn x -> x.dataset.id end))
    end)

    Application.stop(:reaper)
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)
    assert_receive {:DOWN, ^ref, _, _, _}, 5_000
  end
end
