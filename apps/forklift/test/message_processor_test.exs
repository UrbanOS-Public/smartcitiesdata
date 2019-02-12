defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.DatasetStatem
  alias Forklift.MessageProcessor

  test "data messages are routed to the appropriate processor" do
    message = make_message()
    expected = message.value

    expect(DatasetStatem.start_link("cota-whatever"), return: {:ok, :pid_placeholder})
    expect(DatasetStatem.send_message(:pid_placeholder, expected), return: :ok)

    assert MessageProcessor.handle_messages([message]) == :ok
  end

  test "registry messages return :ok" do
    # This test should be expanded once we know more about how registry messages will work. -JP 02/08/18
    message = make_message("registry-topic")

    assert MessageProcessor.handle_messages([message]) == :ok
  end

  def make_message(topic \\ "data-topic") do
    %{
      topic: topic,
      value: "This is a message"
    }
  end
end
