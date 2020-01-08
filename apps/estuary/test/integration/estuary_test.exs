defmodule Estuary.EstuaryTest do
  use ExUnit.Case
  use Placebo
  use Divo
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Estuary.DataWriterHelper

  @endpoints Application.get_env(:estuary, :endpoints)
  @topic Application.get_env(:estuary, :topic)
  # @event_stream_schema_name Application.get_env(:estuary, :event_stream_schema_name)
  # @event_stream_table_name Application.get_env(:estuary, :table_name)

  setup do
    on_exit(fn ->
      DataWriterHelper.delete_all_events_in_table()
    end)
  end

  test "should create history table and confirm all the column exists when estuary starts" do
    expected_columns = [
      ["author", "varchar", "", ""],
      ["create_ts", "bigint", "", ""],
      ["data", "varchar", "", ""],
      ["type", "varchar", "", ""]
    ]

    actual_columns =
      "DESCRIBE history"
      |> Prestige.execute()
      |> Prestige.prefetch()

    assert expected_columns == actual_columns
  end

  test "should persist event to the event_stream table" do
    produce_event(
      @topic,
      %{
        author: "reaper",
        create_ts: 5,
        data: "some data for reaper",
        type: "some type for reaper"
      }
    )

    expected_value = [["reaper", 5, "some data for reaper", "some type for reaper"]]

    eventually(fn ->
      actual_value =
        "'reaper'"
        |> DataWriterHelper.get_events_by_author()

      assert expected_value == actual_value
    end)
  end

  test "should persist batch of events to the event stream" do
    produce_event(@topic, [
      %{
        author: "forklift",
        create_ts: 1,
        data: "some data for forklift",
        type: "some type for forklift"
      },
      %{
        author: "valkyrie",
        create_ts: 2,
        data: "some data for valkyrie",
        type: "some type for valkyrie"
      }
    ])

    expected_value = [
      ["forklift", 1, "some data for forklift", "some type for forklift"],
      ["valkyrie", 2, "some data for valkyrie", "some type for valkyrie"]
    ]

    eventually(fn ->
      actual_value =
        "'forklift', 'valkyrie'"
        |> DataWriterHelper.get_events_by_author()

      assert expected_value == actual_value
    end)
  end

  defp produce_event(topic, payload) do
    Elsa.produce(@endpoints, topic, payload)
  end
end
