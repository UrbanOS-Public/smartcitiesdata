defmodule Estuary.EstuaryTest do
  use ExUnit.Case
  use Placebo
  use Divo
  import SmartCity.TestHelper, only: [eventually: 1]

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

  test "estuary persists event to the event_stream table" do
    produce_event(
      @event_stream_topic,
      ~s({"__brook_struct__":"Elixir.Brook.Event","__struct__":"Elixir.SmartCity.Dataset","author":"reaper","create_ts":5,"data":"some data","forwarded":false,"type":"some type"})
    )

    eventually(fn ->
      events =
        Prestige.execute(
          "SELECT COUNT(*) from #{@event_stream_table_name} WHERE author = 'reaper' and create_ts = 5 and data = 'some data' and type = 'some type'"
        )
        |> Prestige.prefetch()

      assert events == [[1]]
    end)

    Prestige.execute("DELETE from #{@event_stream_table_name}") |> Prestige.prefetch()
  end

  test "estuary persists batch of events to the event stream" do
    produce_event(@event_stream_topic, [
      ~s({"__brook_struct__":"Elixir.Brook.Event","__struct__":"Elixir.SmartCity.Dataset","author":"forklift","create_ts":1,"data":"some data1","forwarded":false,"type":"some type1"}),
      ~s({"__brook_struct__":"Elixir.Brook.Event","__struct__":"Elixir.SmartCity.Dataset","author":"valkyrie","create_ts":2,"data":"some data2","forwarded":false,"type":"some type2"})
    ])

    eventually(fn ->
      events =
        Prestige.execute(
          "SELECT COUNT(*) from #{@event_stream_table_name} WHERE author = 'forklift' and create_ts = 1 and data = 'some data1' and type = 'some type1'"
        )
        |> Prestige.prefetch()

      assert events == [[1]]

      events =
        Prestige.execute(
          "SELECT COUNT(*) from #{@event_stream_table_name} WHERE author = 'valkyrie' and create_ts = 2 and data = 'some data2' and type = 'some type2'"
        )
        |> Prestige.prefetch()

      assert events == [[1]]
    end)

    Prestige.execute("DELETE from #{@event_stream_table_name}") |> Prestige.prefetch()
  end

  test "estuary sends event to the dlq if it is not a properly formatted event" do
    produce_event(@event_stream_topic, {"key", "value"})

    eventually(fn ->
      {:ok, _, events} = Elsa.fetch(@elsa_endpoint, "dead-letters")
      if length(events) > 0 do
        Enum.any?(events, fn event -> event.value == "{\"key\": \"value\"}" end)
      else
        assert false
      end
    end)
  end

  test "estuary sends event to the dlq if it is properly formatted, but doesn't have the right keys" do
    produce_event(@event_stream_topic, ~s({"foo": "bar"}))

    eventually(fn ->
      {:ok, _, events} = Elsa.fetch(@elsa_endpoint, "dead-letters")

      if length(events) > 0 do
        Enum.any?(events, fn event -> event.value == "{\"foo\": \"bar\"}" end)
      else
        assert false
      end
    end)
  end

  defp produce_event(topic, payload) do
    Elsa.produce(@elsa_endpoint, topic, payload)
  end
end
