defmodule Estuary.Query.Helper.PrestigeHelperTest do
  use ExUnit.Case
  use Placebo

  alias Estuary.Query.Helper.PrestigeHelper

  @tag capture_log: true
  test "should return the data by executing the when the query statement is passed" do
    expected_table_data = [
      %{
        "column_1" => "any column_1 data",
        "column_2" => "any column_2 data"
      }
    ]

    allow(Prestige.new_session(any()), return: :do_not_care)
    allow(Prestige.query!(any(), any()), return: :do_not_care)
    allow(Prestige.Result.as_maps(any()), return: expected_table_data)
    assert {:ok, expected_table_data} == PrestigeHelper.execute_query(any())
  end
end
