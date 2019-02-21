defmodule MessageAccumulatorTest do
  use ExUnit.Case, async: true
  use Placebo

  alias Forklift.MessageAccumulator
  alias Forklift.PrestoClient

  test "uploads data when at buffer size" do
    {:ok, pid} = MessageAccumulator.start_link(:dataset_id, timeout: 10_000, batch_size: 3)

    expected_message_set = [
      "Hello there! Buffer 1",
      "Hello there! Buffer 2",
      "Hello there! Buffer 3"
    ]

    expect(PrestoClient.upload_data(:dataset_id, Enum.reverse(expected_message_set)), return: :ok)

    Enum.each(expected_message_set, fn x -> MessageAccumulator.send_message(pid, x) end)
  end

  test "uploads buffer after a timeout" do
    timeout = 1
    {:ok, pid} = MessageAccumulator.start_link(:dataset_id, timeout: timeout)

    expected_message = "Hello There"
    expect(PrestoClient.upload_data(:dataset_id, [expected_message]), return: :ok)

    MessageAccumulator.send_message(pid, expected_message)
    Process.sleep(timeout + 1)
  end
end
