defmodule Estuary.MessageHandlerTest do
  use ExUnit.Case

  import Mox
  import Assertions

  alias Estuary.DataWriterHelper
  alias Estuary.MessageHandler
  alias SmartCity.TestDataGenerator, as: TDG
  alias DeadLetter.Carrier.Test, as: Carrier

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    config = [driver: [module: DeadLetter.Carrier.Test, init_args: [size: 3_000]]]

    {:ok, dlq} = DeadLetter.start_link(config)

    on_exit(fn ->
      ref = Process.monitor(dlq)
      Process.exit(dlq, :normal)
      assert_receive {:DOWN, ^ref, _, _, _}
    end)
  end

  @tag :capture_log
  test "should send the message to dead letter queue when expected fields are not found" do
    payload = %{
      "authors" => DataWriterHelper.make_author(),
      "create_tss" => DataWriterHelper.make_time_stamp(),
      "datas" => Jason.encode!(TDG.create_dataset(%{})),
      "forwarded" => false,
      "types" => "data:ingest:start"
    }

    event = %{
      value: Jason.encode!(payload)
    }

    expected_value = %{
      app: "estuary",
      dataset_id: "Unknown",
      original_message: payload,
      reason: "Required field missing"
    }

    MessageHandler.handle_messages([event])

    assert_async do
      {:ok, actual_value} = Carrier.receive()
      refute actual_value == :empty

      dlq_comparison =
        &(&1.app == &2.app and &1.dataset_id == &2.dataset_id and
            &1.original_message == &2.original_message and &1.reason == &2.reason)

      assert_maps_equal(expected_value, actual_value, dlq_comparison)
    end
  end

  @tag :capture_log
  test "should send the message to dead letter queue when inserting into the database fails" do
    payload = %{
      "author" => DataWriterHelper.make_author(),
      "create_ts" => "'notatimestamp'",
      "data" => Jason.encode!(TDG.create_dataset(%{})),
      "forwarded" => false,
      "type" => "data:ingest:start"
    }

    event = %{
      value: Jason.encode!(payload)
    }

    expected_value = %{
      app: "estuary",
      dataset_id: "Unknown",
      original_message: payload,
      reason: "Presto Error"
    }

    MessageHandler.handle_messages([event])

    assert_async do
      {:ok, actual_value} = Carrier.receive()

      refute actual_value == :empty

      dlq_comparison =
        &(&1.app == &2.app and &1.dataset_id == &2.dataset_id and
            &1.original_message == &2.original_message and &1.reason == &2.reason)

      assert_maps_equal(expected_value, actual_value, dlq_comparison)
    end
  end
end
