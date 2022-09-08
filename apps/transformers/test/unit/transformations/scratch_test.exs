defmodule Transformers.ScratchTest do
  use ExUnit.Case
  use Checkov

  alias Decimal, as: D

  describe "Scratch tests" do
    @tag :wip
    test "explore" do
      a = D.Context.get()
      b = 12.71 / 3.1
      IO.puts b

#      D.Context.set(%D.Context{D.Context.get() | traps: [:division_by_zero]})

      IO.inspect D.Context.get()

      foo = D.div(D.new(4.0), D.new(0))


      IO.puts foo


      assert 1 == 1
    end

    end
end
