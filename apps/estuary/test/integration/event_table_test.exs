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
      "SHOW TABLES LIKE '#{@event_stream_table_name}'"
      |> Prestige.execute()
      |> Prestige.prefetch()

    assert expected_value == actual_value
    assert expected_table_value == actual_table_value
  end

  test "insert_event inserts an event into the #{@event_stream_table_name} table" do
    aloha_events =
      Prestige.execute(
        "SELECT COUNT(*) from #{@event_stream_table_name} WHERE author = 'Steve Aloha' and create_ts = 5 and data = 'some data' and type = 'some type'"
      )
      |> Prestige.prefetch()

    assert aloha_events == [[0]]

    Estuary.EventTable.insert_event(%{
      "author" => "Steve Aloha",
      "create_ts" => 5,
      "data" => "some data",
      "type" => "some type"
    })

    aloha_events =
      Prestige.execute(
        "SELECT COUNT(*) from #{@event_stream_table_name} WHERE author = 'Steve Aloha' and create_ts = 5 and data = 'some data' and type = 'some type'"
      )
      |> Prestige.prefetch()

    assert aloha_events == [[1]]
    Prestige.execute("DELETE from #{@event_stream_table_name}") |> Prestige.prefetch()
  end
end
