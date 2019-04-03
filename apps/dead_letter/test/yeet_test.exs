defmodule YeetTest do
  use ExUnit.Case
  use Placebo
  alias Yeet.KafkaHelper

  @default_stacktrace [
    {:erlang, :/, [1, 0], []},
    {Yeet, :catcher, 1, [file: 'lib/yeet.ex', line: 26]},
    {:erl_eval, :do_apply, 6, [file: 'erl_eval.erl', line: 680]},
    {:elixir, :eval_forms, 4, [file: 'src/elixir.erl', line: 258]},
    {IEx.Evaluator, :handle_eval, 5, [file: 'lib/iex/evaluator.ex', line: 257]},
    {IEx.Evaluator, :do_eval, 3, [file: 'lib/iex/evaluator.ex', line: 237]},
    {IEx.Evaluator, :eval, 3, [file: 'lib/iex/evaluator.ex', line: 215]},
    {IEx.Evaluator, :loop, 1, [file: 'lib/iex/evaluator.ex', line: 103]}
  ]

  @default_original_message %{
    payload: "{}",
    topic: "streaming-raw"
  }

  describe "process_dead_letter/2" do
    test "sends formatted message to kafka" do
      allow(KafkaHelper.produce(any()), return: :ok)

      Yeet.process_dead_letter(@default_original_message, "forklift")

      assert_called(KafkaHelper.produce(%{app: "forklift"}))
    end
  end

  describe "format_message/2" do
    test "returns formatted DLQ message with defaults and empty original message" do
      actual = Yeet.format_message(@default_original_message, "forklift")

      assert match?(
               %{
                 app: "forklift",
                 original_message: %{},
                 exit_code: nil,
                 error: nil,
                 reason: nil,
                 timestamp: %DateTime{}
               },
               actual
             )

      assert Map.get(actual, :stacktrace) =~ "Yeet.format_message"
    end

    test "returns formatted DLQ message with defaults and non-empty original message" do
      actual = Yeet.format_message(@default_original_message, "forklift")

      assert Map.get(actual, :original_message) == %{payload: "{}", topic: "streaming-raw"}
    end

    test "returns formatted DLQ message with a reason" do
      actual = Yeet.format_message("forklift", @default_original_message, reason: "Failed to parse something")

      assert "Failed to parse something" == Map.get(actual, :reason)
    end

    test "returns formatted DLQ message with a stacktrace from Process.info" do
      stacktrace = {:current_stacktrace, @default_stacktrace}

      actual = Yeet.format_message(@default_original_message, "forklift", stacktrace: stacktrace)

      assert Map.get(actual, :stacktrace) == Exception.format_stacktrace(@default_stacktrace)
    end

    test "returns formatted DLQ message with a stacktrace from System.stacktrace" do
      actual = Yeet.format_message(@default_original_message, "forklift", stacktrace: @default_stacktrace)

      assert Map.get(actual, :stacktrace) == Exception.format_stacktrace(@default_stacktrace)
    end

    test "returns formatted DLQ message with an exit" do
      an_exit =
        try do
          raise "Error"
        rescue
          e -> e
        end

      actual = Yeet.format_message("forklift", @default_original_message, exit_code: an_exit)

      assert "%RuntimeError{message: \"Error\"}" == Map.get(actual, :exit_code)
    end

    test "sets the timestamp on DLQ message" do
      actual = Yeet.format_message("forklift", @default_original_message)

      assert %DateTime{} = Map.get(actual, :timestamp)
    end

    test "allows overriding the timestamp on DLQ message" do
      epoch = DateTime.from_unix!(0)

      actual = Yeet.format_message("forklift", @default_original_message, timestamp: epoch)

      assert epoch == Map.get(actual, :timestamp)
    end
  end
end
