defmodule Estuary.StartTest do
  use ExUnit.Case
  use Divo

  @elsa_endpoint Application.get_env(:estuary, :elsa_endpoint)
  @event_stream_topic Application.get_env(:estuary, :event_stream_topic)

  test "Topic is created when Estuary starts" do
    assert Elsa.Topic.exists?(@elsa_endpoint, @event_stream_topic)
  end

  test "should create table if not exists when estuary starts" do
    expected_table_value = [["event_stream"]]

    actual_table_value =
      Prestige.execute("SHOW TABLES LIKE 'event_stream'")
      |> Prestige.prefetch()

    assert expected_table_value == actual_table_value
  end

  test "should check all the columns exists in the table when estuary starts" do
    expected_column_value = [
      ["author", "varchar", "", ""],
      ["create_ts", "bigint", "", ""],
      ["data", "varchar", "", ""],
      ["type", "varchar", "", ""]
    ]

    actual_column_value =
      Prestige.execute("DESCRIBE event_stream")
      |> Prestige.prefetch()

    assert expected_column_value == actual_column_value
  end
end
