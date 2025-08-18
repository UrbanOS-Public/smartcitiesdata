defmodule MessageHandlerTest do
  use ExUnit.Case
  
  import Mox
  
  setup :verify_on_exit!

  describe "handle_messages/2" do
    test "When all messages are successfully added, ack to Kafka" do
      expect(MockProducer, :add_messages, fn :durations, [] -> :ok end)

      assert Flair.MessageHandler.handle_messages([]) == :ack
    end
  end
end
