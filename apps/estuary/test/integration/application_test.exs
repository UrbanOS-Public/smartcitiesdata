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
      "SHOW TABLES LIKE '#{@event_stream_table_name}'"
      |> Prestige.execute()
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
      "DESCRIBE #{@event_stream_table_name}"
      |> Prestige.execute()
      |> Prestige.prefetch()

    assert expected_column_value == actual_column_value
  end

  test "estuary persists event to the event stream" do
    Elsa.produce(
      @elsa_endpoint,
      @event_stream_topic,
      ~s({"__brook_struct__":"Elixir.Brook.Event","__struct__":"Elixir.SmartCity.Dataset","author":"reaper","create_ts":5,"data":"some data","forwarded":false,"type":"some type"})
    )

    Process.sleep(2000)

    aloha_events =
      Prestige.execute(
        "SELECT COUNT(*) from #{@event_stream_table_name} WHERE author = 'reaper' and create_ts = 5 and data = 'some data' and type = 'some type'"
      )
      |> Prestige.prefetch()

    assert aloha_events == [[1]]
  end
end
