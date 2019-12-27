defmodule Estuary.MessageHandlerTestTest do
  use ExUnit.Case
  use Placebo
  use Divo

  # import Mox
  alias Estuary.DataWriterHelper
  alias Estuary.MessageHandler
  alias SmartCity.TestDataGenerator, as: TDG

  test "should successfully insert the message into the database" do
    expected_value = :ok

    actual_value =
      %{
        author: DataWriterHelper.make_author(),
        create_ts: DataWriterHelper.make_time_stamp(),
        data: TDG.create_dataset(%{}),
        forwarded: false,
        type: "data:ingest:start"
      }
      |> MessageHandler.handle_messages()

    assert expected_value == actual_value
  end

  test "should send the message to dead letter queue when expected fields are not found" do
    expected_value = :ok

    actual_value =
      %{
        authors: DataWriterHelper.make_author(),
        create_tss: DataWriterHelper.make_time_stamp(),
        datas: TDG.create_dataset(%{}),
        forwarded: false,
        types: "data:ingest:start"
      }
      |> MessageHandler.handle_messages()

    assert expected_value == actual_value
  end

  test "should send the message to dead letter queue when improper values are inserted to the database" do
    expected_value = :ok

    actual_value =
      %{
        author: DataWriterHelper.make_author(),
        create_ts: "#{DataWriterHelper.make_time_stamp()}",
        data: TDG.create_dataset(%{}),
        forwarded: false,
        type: "data:ingest:start"
      }
      |> MessageHandler.handle_messages()

    assert expected_value == actual_value
  end
end
