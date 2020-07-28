defmodule DeadLetterTest do
  use ExUnit.Case

  describe "reason" do
    test "is formatted for {:failed, reason}" do
      dead_letter =
        DeadLetter.new(reason: {:failed, ArgumentError.exception(message: "some error")})

      assert dead_letter.reason == "** (ArgumentError) some error"
    end

    test "is formatted for any string" do
      dead_letter = DeadLetter.new(reason: "some error")

      assert dead_letter.reason == "** (ErlangError) Erlang error: \"some error\""
    end

    test "is formatted for  any atom" do
      dead_letter = DeadLetter.new(reason: :some_error)

      assert dead_letter.reason == "** (ErlangError) Erlang error: :some_error"
    end

    test "is formatted for {kind, reason, stacktrace}" do
      reason =
        {_, _, stacktrace} =
        try do
          raise ArgumentError, message: "some error"
        catch
          kind, error ->
            {kind, error, __STACKTRACE__}
        end

      dead_letter = DeadLetter.new(reason: reason)

      assert dead_letter.reason == "** (ArgumentError) some error"
      assert dead_letter.stacktrace == Exception.format_stacktrace(stacktrace)
    end
  end
end
