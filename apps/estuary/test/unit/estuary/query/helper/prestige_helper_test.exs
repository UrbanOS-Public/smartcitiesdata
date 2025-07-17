defmodule Estuary.Query.Helper.PrestigeHelperTest do
  use ExUnit.Case, async: true
  import Mox

  alias Estuary.Query.Helper.PrestigeHelper

  @tag capture_log: true
  test "should return the data by executing the when the query statement is passed" do
    expected_table_data = [
      %{
        "column_1" => "any column_1 data",
        "column_2" => "any column_2 data"
      }
    ]

    expect(Prestige.Mock, :new_session, fn _ -> :connection end)
    expect(Prestige.Mock, :stream!, 2, fn _, _ ->
      {:ok,
       %Prestige.Result{
         columns: [%Prestige.ColumnDefinition{name: "column_1"}, %Prestige.ColumnDefinition{name: "column_2"}],
         rows: [["any column_1 data", "any column_2 data"]]
       }}
    end)

    {:ok, returned_table_data} = PrestigeHelper.execute_query_stream("whatever")
    assert expected_table_data == Enum.to_list(returned_table_data)
  end
end
