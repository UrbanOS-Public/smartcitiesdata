defmodule Estuary.ApplicationTest do
  use ExUnit.Case
  use Placebo
  use Divo

  @elsa_endpoint Application.get_env(:estuary, :elsa_endpoint)
  @event_stream_topic Application.get_env(:estuary, :event_stream_topic)
  @event_stream_table_name Application.get_env(:estuary, :event_stream_table_name)

  test "Topic is created when Estuary starts" do
    assert Elsa.Topic.exists?(@elsa_endpoint, @event_stream_topic)
  end

  test "should create event_stream table when estuary starts" do
    expected_table_value = [[@event_stream_table_name]]

    actual_table_value =
      Prestige.execute("SHOW TABLES LIKE '#{@event_stream_table_name}'")
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
      Prestige.execute("DESCRIBE #{@event_stream_table_name}")
      |> Prestige.prefetch()

    assert expected_column_value == actual_column_value
  end
end
