# defmodule Estuary.InsertTest do
#   use ExUnit.Case
#   use Placebo

#   describe "insert_event_to_table/1" do
#     setup do
#       event =
#         %{
#           "author" => "good author",
#           "create_ts" => "23",
#           "data" => "good data",
#           "type" => "good type"
#         }
#         |> event_struct
#         |> Jason.decode!()

#       %{
#         event: event
#       }
#     end

#     test "should raise an error if there is a Prestige.ConnectionError", %{
#       event: event
#     } do
#       allow(Prestige.execute(any()),
#         exec: fn _x ->
#           raise Prestige.ConnectionError, message: "Error connecting to Presto."
#         end
#       )

#       assert_raise Prestige.ConnectionError, "Error connecting to Presto.", fn ->
#         Estuary.EventTable.insert_event_to_table(event)
#       end
#     end

#     defp event_struct(event_data) do
#       ~s({
#                 "__brook_struct__":"Elixir.Brook.Event",
#                 "__struct__":"Elixir.SmartCity.Dataset",
#                 "author":"#{event_data["author"]}",
#                 "create_ts":"#{event_data["create_ts"]}",
#                 "data":"#{event_data["data"]}",
#                 "forwarded":false,
#                 "type":"#{event_data["type"]}"
#                 })
#     end
#   end
# end
