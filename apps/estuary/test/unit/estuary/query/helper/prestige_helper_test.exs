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

    allow(Prestige.new_session(any()), return: :connection)
    allow(Prestige.stream!(any(), any()), return: [:result])

    allow(Prestige.Result.as_maps(:result),
      return: expected_table_data
    )

    {:ok, returned_table_data} = PrestigeHelper.execute_query_stream("whatever")
    assert expected_table_data == Enum.to_list(returned_table_data)
  end
end
