defmodule Forklift.IntegrationTest do
  use ExUnit.Case
  require Logger
  use Divo
  import Checkov
  import SmartCity.Event, only: [dataset_update: 0]

  data_test "creates hive.default.#{system_name} with correct schema" do
    assert describe_table("hive.default.#{system_name}") == []

    dataset =
      FixtureHelper.dataset(
        id: "id1",
        technical: %{systemName: system_name, schema: desired_schema, sourceType: "stream"}
      )

    Brook.Event.send(:forklift, dataset_update(), :author, dataset)

    Patiently.wait_for!(
      fn ->
        actual_schema = describe_table("hive.default.#{system_name}")

        Logger.debug(fn ->
          "Waiting for #{inspect(actual_schema)} to equal #{inspect(expected_schema)}"
        end)

        actual_schema == expected_schema
      end,
      dwell: 1000,
      max_tries: 20
    )

    where([
      [:system_name, :desired_schema, :expected_schema],
      [
        "carpenter__test_table_one",
        [%{name: "name", type: "string"}],
        [%{"Column" => "name", "Comment" => "", "Extra" => "", "Type" => "varchar"}]
      ],
      [
        "carpenter__test_table_two",
        [%{name: "anothername", type: "integer"}],
        [%{"Column" => "anothername", "Comment" => "", "Extra" => "", "Type" => "integer"}]
      ],
      [
        "carpenter__decimal_table",
        [%{name: "no_precision", type: "decimal"}, %{name: "optimized_3_precision", type: "decimal(18,3)"}],
        [
          %{"Column" => "no_precision", "Comment" => "", "Extra" => "", "Type" => "decimal(38,0)"},
          %{"Column" => "optimized_3_precision", "Comment" => "", "Extra" => "", "Type" => "decimal(18,3)"}
        ]
      ],
      [
        "carpenter__test_table_list",
        [%{name: "names", type: "list", itemType: "string"}],
        [%{"Column" => "names", "Comment" => "", "Extra" => "", "Type" => "array(varchar)"}]
      ],
      [
        "carpenter__test_table_map",
        [%{name: "person", type: "map", subSchema: [%{name: "power_level", type: "integer"}]}],
        [%{"Column" => "person", "Comment" => "", "Extra" => "", "Type" => "row(power_level integer)"}]
      ],
      [
        "carpenter__test_table_list_of_rows",
        [%{name: "people", type: "list", itemType: "map", subSchema: [%{name: "power_level", type: "integer"}]}],
        [%{"Column" => "people", "Comment" => "", "Extra" => "", "Type" => "array(row(power_level integer))"}]
      ]
    ])
  end

  test "invalid column names are escaped" do
    dataset =
      FixtureHelper.dataset(
        id: "1234-5678-9101",
        technical: %{systemName: "org__dataset", schema: [%{name: "on", type: "boolean"}], sourceType: "stream"}
      )

    Brook.Event.send(:forklift, dataset_update(), :author, dataset)

    expected = [
      %{
        "Column" => "on",
        "Comment" => "",
        "Extra" => "",
        "Type" => "boolean"
      }
    ]

    Patiently.wait_for!(
      fn ->
        actual = describe_table("hive.default.org__dataset")

        Logger.debug(fn ->
          "INVALID COLUMN NAMES ESCAPED::Waiting for #{inspect(actual)} to equal #{inspect(expected)}"
        end)

        actual == expected
      end,
      dwell: 1000,
      max_tries: 20
    )
  end

  defp describe_table(table_name) do
    "describe #{table_name}"
    |> Prestige.execute(rows_as_maps: true)
    |> Prestige.prefetch()
  rescue
    error ->
      Logger.warn("Syntax error: #{inspect(error)}")
      []
  end
end
