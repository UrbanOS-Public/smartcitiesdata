defmodule Estuary.EventTableTest do
  use ExUnit.Case
  use Divo

  alias Estuary.EventTable
  alias Estuary.EventTableHelper

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

  test "should insert event to event_stream table" do
    expected_value_after_insert = [["Steve", 5, "some data", "some type"]]

    %{
      "author" => "Steve",
      "create_ts" => 5,
      "data" => "some data",
      "type" => "some type"
    }
    |> EventTable.insert_event_to_table()

    actual_value_after_insert =
      "'Steve'"
      |> EventTableHelper.select_table_data()

    assert expected_value_after_insert == actual_value_after_insert
    EventTableHelper.delete_table_data()
  end

  test "should fail when improper value of timestamp is passed" do
    expected_value = "SYNTAX_ERROR"

    bad_event_value = %{
      "author" => "Steve",
      "create_ts" => "'5'",
      "data" => "some data",
      "type" => "some type"
    }

    {:error, %Prestige.Error{name: error}} = EventTable.insert_event_to_table(bad_event_value)

    assert expected_value == error
  end
end
