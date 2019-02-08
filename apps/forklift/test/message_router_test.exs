defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  alias Forklift.DatasetServer
  alias Forklift.MessageProcessor

  test "data messages are routed to the appropriate processor" do
    expect(DatasetServer.start_link("cota-whatever"), return: {:ok, :pid_placeholder})
    expect(DatasetServer.ingest_message(:pid_placeholder, make_message()), return: :ok)

    assert MessageProcessor.handle_message(make_message()) == :ok
  end

  test "registry messages return :ok" do
    # This test should be expanded once we know more about how registry messages will work. -JP 02/08/18
    message = make_message("registry-topic") |> IO.inspect(label: "message_router_test.exs:17")

    assert MessageProcessor.handle_message(message) == :ok
  end

  def make_message(topic \\ "data-topic") do
    %{
      topic: topic,
      message: "this is a message"
    }
  end
end
