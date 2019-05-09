defmodule MessageProcessorTest do
  use ExUnit.Case
  use Placebo

  describe "handle_message_set/2" do
    test "When all task are completed successfully returns good" do
      allow(Flair.Producer.add_messages(any(), any()), return: true)

      message_set = []
      state = %{}

      assert {:async_commit, state} ==
               Flair.MessageProcessor.handle_message_set(message_set, state)
    end

    test "When a task times out, returns error and aborts commit upstream" do
      allow(Flair.Producer.add_messages(:durations, any()),
        exec: fn _, _ -> Process.sleep(100) end
      )

      message_set = []
      state = %{}

      assert_raise(
        RuntimeError,
        fn -> Flair.MessageProcessor.handle_message_set(message_set, state) end
      )
    end

    @tag :capture_log
    test "When a task dies due to an error, returns error and aborts commit upstream" do
      Process.flag(:trap_exit, true)

      allow(Flair.Producer.add_messages(:durations, any()),
        exec: fn _, _ -> raise "errors and explosions" end
      )

      message_set = []
      state = %{}

      assert_raise(
        RuntimeError,
        fn -> Flair.MessageProcessor.handle_message_set(message_set, state) end
      )
    end
  end
end
