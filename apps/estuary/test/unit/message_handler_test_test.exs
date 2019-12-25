defmodule Estuary.MessageHandlerTestTest do
  use ExUnit.Case

  # import Mox
  alias Estuary.MessageHandler
  alias SmartCity.TestDataGenerator, as: TDG

  @event_stream_table_name Application.get_env(:estuary, :event_stream_table_name)

  test "should test message handler when given ingest SmartCity Dataset struct" do
    dataset = TDG.create_dataset(%{})

    event = %{
      author: "some_author",
      create_ts: 1_575_308_549_008,
      data: dataset,
      forwarded: false,
      type: "data:ingest:start"
    }

    # expected_value = [
    #   %{
    #     payload: %{
    #       "author" => "some_author",
    #       "create_ts" => 1_575_308_549_008,
    #       "data" => dataset,
    #       "type" => "data:ingest:start"
    #     }
    #   }
    # ]
    event
    |> event_struct()
    |> MessageHandler.handle_messages(event)
    # actual_value = MessageHandler.handle_messages(dataset)
    # assert expected_value == actual_value
  end

  defp event_struct(event_data) do
    ~s({
      "__brook_struct__":"Elixir.Brook.Event",
      "__struct__":"Elixir.SmartCity.Dataset",
      "author":"#{event_data["author"]}",
      "create_ts":"#{event_data["create_ts"]}",
      "data":"#{event_data["data"]}",
      "forwarded":false,
      "type":"#{event_data["type"]}"
      })
  end
end
