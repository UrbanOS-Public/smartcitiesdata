defmodule Estuary.EstuaryTest do
  use ExUnit.Case
  use Placebo
  use Divo
  import SmartCity.TestHelper, only: [eventually: 1]

  alias Estuary.DataWriterHelper

  @endpoints Application.get_env(:estuary, :endpoints)
  @topic Application.get_env(:estuary, :topic)

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
    # Can we use produce sync here instead of the sleep?
    Process.sleep(2_000)
    produce_event(
      @topic,
      Jason.encode!(%Brook.Event{
        type: "some type for reaper",
        author: "reaper",
        create_ts: 5,
        data: "some data for reaper",
        forwarded: false
      })
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
    Process.sleep(2_000)

    produce_event(@topic,
    [Jason.encode!(%Brook.Event{
        type: "some type for forklift",
        author: "forklift",
        create_ts: 1,
        data: "some data for forklift"
      }),
    Jason.encode!(%Brook.Event{
        type: "some type for valkyrie",
        author: "valkyrie",
        create_ts: 2,
        data: "some data for valkyrie"
      }
    )])

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
