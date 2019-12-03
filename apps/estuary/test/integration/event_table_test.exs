defmodule Estuary.EventTableTest do
  use ExUnit.Case
  use Divo

  alias Estuary.EventTable

  @event_stream_table_name Application.get_env(:estuary, :event_stream_table_name)

  test "create_table is idempotent" do
    expected_value = [[true]]
    expected_table_value = [[@event_stream_table_name]]
    EventTable.create_table()
    actual_value = EventTable.create_table()

    actual_table_value =
      Prestige.execute("SHOW TABLES LIKE '#{@event_stream_table_name}'")
      |> Prestige.prefetch()

    assert expected_value == actual_value
    assert expected_table_value == actual_table_value
  end
end
