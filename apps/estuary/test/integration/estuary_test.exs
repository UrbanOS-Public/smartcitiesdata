defmodule Estuary.EstuaryTest do
  use ExUnit.Case
  use Placebo
  use Divo
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Estuary.EventTableHelper

  @elsa_endpoint Application.get_env(:estuary, :elsa_endpoint)
  @event_stream_topic Application.get_env(:estuary, :event_stream_topic)
  @event_stream_table_name Application.get_env(:estuary, :event_stream_table_name)

  test "should create topic when estuary starts" do
    assert Elsa.Topic.exists?(@elsa_endpoint, @event_stream_topic)
  end

  test "should create event_stream table and confirm all the column exists when estuary starts" do
    expected_columns = [
      ["author", "varchar", "", ""],
      ["create_ts", "bigint", "", ""],
      ["data", "varchar", "", ""],
      ["type", "varchar", "", ""]
    ]

    actual_columns =
      "DESCRIBE #{@event_stream_table_name}"
      |> Prestige.execute()
      |> Prestige.prefetch()

    assert expected_columns == actual_columns
  end

  test "should persist event to the event_stream table" do
    produce_event(
      @event_stream_topic,
      ~s({"__brook_struct__":"Elixir.Brook.Event",
      "__struct__":"Elixir.SmartCity.Dataset","author":"reaper","create_ts":5,"data":"some data for reaper","forwarded":false,"type":"some type for reaper"})
    )

    expected_value = [["reaper", 5, "some data for reaper", "some type for reaper"]]

    eventually(fn ->
      actual_value =
        "'reaper'"
        |> EventTableHelper.select_table_data()

      assert expected_value == actual_value
    end)

    EventTableHelper.delete_table_data()
  end

  test "should persist batch of events to the event stream" do
    produce_event(@event_stream_topic, [
      ~s({"__brook_struct__":"Elixir.Brook.Event",
      "__struct__":"Elixir.SmartCity.Dataset","author":"forklift","create_ts":1,"data":"some data for forklift","forwarded":false,"type":"some type for forklift"}),
      ~s({"__brook_struct__":"Elixir.Brook.Event",
      "__struct__":"Elixir.SmartCity.Dataset","author":"valkyrie","create_ts":2,"data":"some data for valkyrie","forwarded":false,"type":"some type for valkyrie"})
    ])

    expected_value = [
      ["forklift", 1, "some data for forklift", "some type for forklift"],
      ["valkyrie", 2, "some data for valkyrie", "some type for valkyrie"]
    ]

    eventually(fn ->
      actual_value =
        "'forklift', 'valkyrie'"
        |> EventTableHelper.select_table_data()

      assert expected_value == actual_value
    end)

    EventTableHelper.delete_table_data()
  end

  test "should send event to the dlq if it is not a properly formatted event" do
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

  test "should send event to the dlq if it is properly formatted, but doesn't have the right keys" do
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
