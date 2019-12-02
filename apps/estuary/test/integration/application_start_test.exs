defmodule Estuary.StartTest do
  use ExUnit.Case
  use Divo

  @elsa_endpoint Application.get_env(:estuary, :elsa_endpoint)
  @event_stream_topic Application.get_env(:estuary, :event_stream_topic)

  test "Topic is created when Estuary starts" do
    assert Elsa.Topic.exists?(@elsa_endpoint, @event_stream_topic)
  end

  test "should create table when estuary starts" do
    table_name = "event_stream"
    query = "SHOW TABLES LIKE '#{table_name}'"
    expected_table_value = [[table_name]]
    actual_table_value = Prestige.execute(query)
    |> Prestige.prefetch
    assert expected_table_value == actual_table_value
  end
end
