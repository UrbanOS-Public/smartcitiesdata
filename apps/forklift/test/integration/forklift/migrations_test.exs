defmodule Forklift.MigrationsTest do
  use ExUnit.Case
  use Divo, auto_start: false

  import SmartCity.TestHelper
  import SmartCity.Event, only: [data_write_complete: 0]

  @tag :capture_log
  test "should run the last insert date migration" do
    Application.ensure_all_started(:redix)

    last_insert_dates = %{
      "forklift:last_insert_date:38a830be-1408-41ae-8d2b-e1309f41c4cc" => "2019-10-04T17:44:02.645233Z",
      "forklift:last_insert_date:043c12aa-0964-4a25-b74a-62b4eebdc0fa" => "2019-11-04T17:44:02.645233Z",
      "forklift:last_insert_date:7ab08634-3eda-4b05-a754-5eb6cab31326" => "2019-12-04T17:44:02.645233Z"
    }

    expected = [
      %{
        "id" => "38a830be-1408-41ae-8d2b-e1309f41c4cc",
        "timestamp" => "2019-10-04T17:44:02.645233Z"
      },
      %{
        "id" => "043c12aa-0964-4a25-b74a-62b4eebdc0fa",
        "timestamp" => "2019-11-04T17:44:02.645233Z"
      },
      %{
        "id" => "7ab08634-3eda-4b05-a754-5eb6cab31326",
        "timestamp" => "2019-12-04T17:44:02.645233Z"
      }
    ]

    {:ok, redix} = Redix.start_link(Keyword.put(Application.get_env(:redix, :args), :name, :redix))

    Process.unlink(redix)

    Enum.each(last_insert_dates, fn {k, v} -> Redix.command(:redix, ["SET", k, v]) end)

    kill(redix)

    Application.ensure_all_started(:forklift)

    eventually(fn ->
      actual = get_data_write_complete_events()

      assert Enum.count(actual) == 3

      assert MapSet.new(actual) == MapSet.new(expected)

      last_insert_dates
      |> Map.keys()
      |> Enum.each(fn k -> assert Redix.command!(:redix, ["TTL", k]) > 0 end)
    end)

    Application.stop(:forklift)
  end

  def get_data_write_complete_events() do
    Elsa.Fetch.search_keys([{'127.0.0.1', 9092}], "event-stream", data_write_complete())
    |> Enum.to_list()
    |> Enum.map(fn %Elsa.Message{value: value} ->
      Jason.decode!(value)["data"] |> Jason.decode!() |> Map.drop(["__brook_struct__"])
    end)
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)
    assert_receive {:DOWN, ^ref, _, _, _}, 5_000
  end
end
