defmodule Pipeline.TestHandler do
  use Elsa.Consumer.MessageHandler

  def init(_ \\ []) do
    {:ok, []}
  end

  def handle_messages(messages, state) do
    Registry.put_meta(Pipeline.TestRegistry, :messages, messages)
    {:ack, state}
  end
end

ExUnit.start()
