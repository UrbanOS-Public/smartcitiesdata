defmodule YeetTest do
  use ExUnit.Case

  test "returns formatted DLQ message with defaults and empty original message" do
    original_message = %{}

    actual = Yeet.format_message(original_message, "forklift")

    assert match?(
             %{
               app: "forklift",
               original_message: %{},
               stacktrace: nil,
               exit: nil,
               error: nil,
               reason: nil,
               timestamp: %DateTime{}
             },
             actual
           )
  end

  test "returns formatted DLQ message with defaults and non-empty original message" do
    original_message = %{
      payload: "{}",
      topic: "streaming-raw"
    }

    actual = Yeet.format_message(original_message, "forklift")

    assert Map.get(actual, :original_message) == %{payload: "{}", topic: "streaming-raw"}
  end

  test "returns formatted DLQ message with a reason" do
    original_message = %{
      payload: "{}",
      topic: "streaming-raw"
    }

    actual = Yeet.format_message("forklift", original_message, reason: "Failed to parse something")

    assert "Failed to parse something" == Map.get(actual, :reason)
  end

  test "returns formatted DLQ message with a stacktrace" do
    original_message = %{
      payload: "{}",
      topic: "streaming-raw"
    }

    stacktrace =
      {:error,
       [
         {:erlang, :/, [1, 0], []},
         {Yeet, :catcher, 1, [file: 'lib/yeet.ex', line: 26]},
         {:erl_eval, :do_apply, 6, [file: 'erl_eval.erl', line: 680]},
         {:elixir, :eval_forms, 4, [file: 'src/elixir.erl', line: 258]},
         {IEx.Evaluator, :handle_eval, 5, [file: 'lib/iex/evaluator.ex', line: 257]},
         {IEx.Evaluator, :do_eval, 3, [file: 'lib/iex/evaluator.ex', line: 237]},
         {IEx.Evaluator, :eval, 3, [file: 'lib/iex/evaluator.ex', line: 215]},
         {IEx.Evaluator, :loop, 1, [file: 'lib/iex/evaluator.ex', line: 103]}
       ]}

    actual = Yeet.format_message(original_message, "forklift", stacktrace: stacktrace)

    assert Map.get(actual, :stacktrace) ==
             "    :erlang./(1, 0)\n    (yeet) lib/yeet.ex:26: Yeet.catcher/1\n    (stdlib) erl_eval.erl:680: :erl_eval.do_apply/6\n    (elixir) src/elixir.erl:258: :elixir.eval_forms/4\n    lib/iex/evaluator.ex:257: IEx.Evaluator.handle_eval/5\n    lib/iex/evaluator.ex:237: IEx.Evaluator.do_eval/3\n    lib/iex/evaluator.ex:215: IEx.Evaluator.eval/3\n    lib/iex/evaluator.ex:103: IEx.Evaluator.loop/1\n"
  end

  test "returns formatted DLQ message with an exit" do
    original_message = %{
      payload: "{}",
      topic: "streaming-raw"
    }

    an_exit =
      try do
        raise "Error"
      rescue
        e -> e
      end

    actual = Yeet.format_message("forklift", original_message, exit: an_exit)

    assert "%RuntimeError{message: \"Error\"}" == Map.get(actual, :exit)
  end

  test "sets the timestamp on DLQ message" do
    original_message = %{}
    actual = Yeet.format_message("forklift", original_message)

    assert %DateTime{} = Map.get(actual, :timestamp)
  end

  test "allows overriding the timestamp on DLQ message" do
    epoch = DateTime.from_unix!(0)
    original_message = %{}
    actual = Yeet.format_message("forklift", original_message, timestamp: epoch)

    assert epoch == Map.get(actual, :timestamp)
  end
end
