defmodule Andi.DatasetMigrationTest do
  use ExUnit.Case
  use Divo, auto_start: false

  import Andi
  import SmartCity.TestHelper
  alias SmartCity.TestDataGenerator, as: TDG

  @instance Andi.instance_name()

  @tag :capture_log
  test "should run the downcase migration" do
    Application.ensure_all_started(:redix)
    Application.ensure_all_started(:faker)

    {:ok, redix} = Redix.start_link(host: Application.get_env(:redix, :host), name: :redix)
    Process.unlink(redix)

    {:ok, brook} =
      Brook.start_link(
        Application.get_env(:andi, :brook)
        |> Keyword.delete(:driver)
        |> Keyword.put(:instance, @instance)
      )

    Process.unlink(brook)

    dataset_with_lowercase_schema_id = 1
    dataset_mixed_schema_id = 2
    invalid_dataset_id = 3

    lower_case_schema = [%{name: "lowercase_name"}]
    mixed_case_schema = [%{name: "mIxEdNam_E"}]
    expected_mixed_case_schema = [%{name: "mixednam_e"}]

    Brook.Test.with_event(
      @instance,
      Brook.Event.new(type: "andi_config:migration", author: "migration", data: %{}),
      fn ->
        Brook.ViewState.merge(:dataset, dataset_with_lowercase_schema_id, %{
          dataset: TDG.create_dataset(id: dataset_with_lowercase_schema_id, technical: %{schema: lower_case_schema})
        })

        Brook.ViewState.merge(:dataset, dataset_mixed_schema_id, %{
          dataset: TDG.create_dataset(id: dataset_mixed_schema_id, technical: %{schema: mixed_case_schema})
        })

        Brook.ViewState.merge(:dataset, invalid_dataset_id, %{})
      end
    )

    kill(brook)
    kill(redix)

    Application.ensure_all_started(:andi)

    Process.sleep(10_000)

    eventually(fn ->
      assert lower_case_schema ==
               Brook.get!(@instance, :dataset, dataset_with_lowercase_schema_id)["technical"]["schema"]

      assert expected_mixed_case_schema ==
               Brook.get!(@instance, :dataset, dataset_mixed_schema_id)["technical"]["schema"]
    end)

    Application.stop(:andi)
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)
    assert_receive {:DOWN, ^ref, _, _, _}, 5_000
  end
end
