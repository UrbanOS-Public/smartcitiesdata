defmodule MessageHandlerTest do
  use ExUnit.Case
  use Placebo

  describe "handle_messages/2" do
    test "When all messages are successfully added, ack to Kafka" do
      allow(Flair.Producer.add_messages(any(), any()), return: :ok)

      assert Flair.MessageHandler.handle_messages([]) == :ack
    end
  end
end
