defmodule DatasetStatemTest do
  use ExUnit.Case, async: true
  use Placebo

  alias Forklift.DatasetStatem
  alias Forklift.PrestoClient

  test "uploads data when at buffer size" do
    {:ok, pid} = DatasetStatem.start_link(:dataset_id, timeout: 10000, batch_size: 3)

    expected_message_set = [
      "Hello there! Buffer 1",
      "Hello there! Buffer 2",
      "Hello there! Buffer 3"
    ]

    expect(PrestoClient.upload_data(:dataset_id, Enum.reverse(expected_message_set)), return: :ok)

    Enum.each(expected_message_set, fn x -> DatasetStatem.send_message(pid, x) end)
  end

  test "uploads buffer after a timeout" do
    timeout = 1
    {:ok, pid} = DatasetStatem.start_link(:dataset_id, timeout: timeout)

    expected_message = "Hello There"
    expect(PrestoClient.upload_data(:dataset_id, [expected_message]), return: :ok)

    DatasetStatem.send_message(pid, expected_message)
    Process.sleep(timeout + 1)
  end
end
