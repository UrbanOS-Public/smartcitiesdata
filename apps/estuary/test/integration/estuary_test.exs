# defmodule Estuary.EstuaryTest do
#   use ExUnit.Case
#   use Placebo
#   use Divo
#   import SmartCity.TestHelper, only: [eventually: 1]

#   alias Estuary.DataWriterHelper

#   @elsa_endpoint Application.get_env(:estuary, :elsa_endpoint)
#   @event_stream_topic Application.get_env(:estuary, :event_stream_topic)
#   # @event_stream_schema_name Application.get_env(:estuary, :event_stream_schema_name)
#   # @event_stream_table_name Application.get_env(:estuary, :table_name)

#   setup do
#     on_exit(fn ->
#       DataWriterHelper.delete_all_events_in_table()
#     end)
#   end

#   test "should create topic when estuary starts" do
#     assert Elsa.Topic.exists?(@elsa_endpoint, @event_stream_topic)
#   end

#   test "should create history table and confirm all the column exists when estuary starts" do
#     expected_columns = [
#       ["author", "varchar", "", ""],
#       ["create_ts", "bigint", "", ""],
#       ["data", "varchar", "", ""],
#       ["type", "varchar", "", ""]
#     ]

#     actual_columns =
#       "DESCRIBE history"
#       |> Prestige.execute()
#       |> Prestige.prefetch()

#     assert expected_columns == actual_columns
#   end

#   test "should persist event to the event_stream table" do
#     produce_event(
#       @event_stream_topic,
#       %{
#         "author" => "reaper",
#         "create_ts" => 5,
#         "data" => "some data for reaper",
#         "type" => "some type for reaper"
#       }
#       |> event_struct()
#     )

#     expected_value = [["reaper", 5, "some data for reaper", "some type for reaper"]]

#     eventually(fn ->
#       actual_value =
#         "'reaper'"
#         |> DataWriterHelper.get_events_by_author()

#       assert expected_value == actual_value
#     end)
#   end

#   test "should persist batch of events to the event stream" do
#     produce_event(@event_stream_topic, [
#       %{
#         "author" => "forklift",
#         "create_ts" => 1,
#         "data" => "some data for forklift",
#         "type" => "some type for forklift"
#       }
#       |> event_struct(),
#       %{
#         "author" => "valkyrie",
#         "create_ts" => 2,
#         "data" => "some data for valkyrie",
#         "type" => "some type for valkyrie"
#       }
#       |> event_struct()
#     ])

#     expected_value = [
#       ["forklift", 1, "some data for forklift", "some type for forklift"],
#       ["valkyrie", 2, "some data for valkyrie", "some type for valkyrie"]
#     ]

#     eventually(fn ->
#       actual_value =
#         "'forklift', 'valkyrie'"
#         |> DataWriterHelper.get_events_by_author()

#       assert expected_value == actual_value
#     end)
#   end

#   test "should send event to the dlq if it is not a properly formatted event for Jason decoding" do
#     produce_event(@event_stream_topic, {"some_improper_event_key", "some_improper_event_value"})

#     expected_value = [
#       "key: \\\"some_improper_event_key\\\"",
#       "value: \\\"some_improper_event_value\\\""
#     ]

#     eventually(fn ->
#       assert is_in_dlq(expected_value)
#     end)
#   end

#   test "should send event to the dlq if it is properly formatted, but doesn't have the right keys" do
#     produce_event(@event_stream_topic, ~s({"some_bad_key": "some_bad_value"}))
#     expected_value = ["{\\\\\\\"some_bad_key\\\\\\\": \\\\\\\"some_bad_value\\\\\\\"}"]

#     eventually(fn ->
#       assert is_in_dlq(expected_value)
#     end)
#   end

#   test "should dlq message if it fail to insert, because values are not the right type" do
#     event_data = %{
#       "author" => "Me",
#       "create_ts" => "'5'",
#       "data" => "some data",
#       "type" => "some type"
#     }

#     expected_value = "\\\"create_ts\\\" => \\\"'5'\\\""

#     produce_event(
#       @event_stream_topic,
#       event_struct(event_data)
#     )

#     eventually(fn ->
#       assert is_in_dlq(expected_value)
#     end)
#   end

#   defp produce_event(topic, payload) do
#     Elsa.produce(@elsa_endpoint, topic, payload)
#   end

#   defp event_struct(event_data) do
#     ~s({
#       "__brook_struct__":"Elixir.Brook.Event",
#       "__struct__":"Elixir.SmartCity.Dataset",
#       "author":"#{event_data["author"]}",
#       "create_ts":"#{event_data["create_ts"]}",
#       "data":"#{event_data["data"]}",
#       "forwarded":false,
#       "type":"#{event_data["type"]}"
#       })
#   end

#   defp is_in_dlq(expected_value) do
#     {:ok, _, events} = Elsa.fetch(@elsa_endpoint, "dead-letters")
#     Enum.any?(events, fn event -> String.contains?(event.value, expected_value) end)
#   end
# end
