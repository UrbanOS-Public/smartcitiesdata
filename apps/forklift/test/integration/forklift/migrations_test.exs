defmodule Forklift.MigrationsTest do
  use ExUnit.Case
  use Divo, auto_start: false

  import SmartCity.TestHelper
  alias SmartCity.TestDataGenerator, as: TDG
  import SmartCity.Event, only: [data_write_complete: 0]

  require Forklift
  @instance Forklift.instance_name()

  @tag :capture_log
  test "should run the last insert date migration" do
    Application.ensure_all_started(:redix)

    last_insert_dates = %{
      "forklift:last_insert_date:38a830be-1408-41ae-8d2b-e1309f41c4cc" => "2019-10-04T17:44:02.645233Z",
      "forklift:last_insert_date:043c12aa-0964-4a25-b74a-62b4eebdc0fa" => "2019-11-04T17:44:02.645233Z",
      "forklift:last_insert_date:7ab08634-3eda-4b05-a754-5eb6cab31326" => "2019-12-04T17:44:02.645233Z"
    }

    {:ok, redix} = Redix.start_link(host: Application.get_env(:redix, :host), name: :redix)
    Process.unlink(redix)

    Enum.each(last_insert_dates, fn {k, v} -> Redix.command(:redix, ["SET", k, v]) end)

    kill(redix)

    Application.ensure_all_started(:forklift)

    Process.sleep(30_000)

    eventually(fn ->
      Elsa.Fetch.fetch([{'127.0.0.1', 9092}], "event-stream")
      assert Elsa.Fetch.search_keys([{'127.0.0.1', 9092}], "event-stream", data_write_complete()) |> Enum.to_list() |> length == 3
    end)

    Application.stop(:forklift)
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)
    assert_receive {:DOWN, ^ref, _, _, _}, 5_000
  end
end
