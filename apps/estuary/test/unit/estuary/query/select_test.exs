defmodule Estuary.Query.SelectTest do
  use ExUnit.Case
  use Placebo
  alias Estuary.Query.Select

  test "display Level of Access as public when private is false" do
    table_schema = %{
      "columns" => ["author", "create_ts", "data", "type"],
      "table_name" => "any_table",
      "order_by" => "create_ts",
      "order" => "DESC",
      "limit" => 1000
    }

    expected_events = [
      %{
        "author" => "Author-2020-01-21 23:29:20.171519Z",
        "create_ts" => 1_579_649_360,
        "data" => "Data-2020-01-21 23:29:20.171538Z",
        "type" => "Type-2020-01-21 23:29:20.171543Z"
      },
      %{
        "author" => "Author-2020-01-21 23:25:52.522084Z",
        "create_ts" => 1_579_649_152,
        "data" => "Data-2020-01-21 23:25:52.522107Z",
        "type" => "Type-2020-01-21 23:25:52.522111Z"
      }
    ]

    allow(Prestige.execute(any(), any()), return: :do_not_care)
    allow(Prestige.prefetch(any()), return: expected_events)
    assert {:ok, expected_events} == Select.select_table(table_schema)
  end
end
