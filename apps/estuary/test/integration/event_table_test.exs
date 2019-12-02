defmodule Estuary.EventTableTest do
  use ExUnit.Case
  use Divo

  alias Estuary.EventTable

  test "create_table is idempotent" do
    expected_value = [[true]]
    EventTable.create_table()
    actual_value = EventTable.create_table()
    assert expected_value == actual_value
  end
end
