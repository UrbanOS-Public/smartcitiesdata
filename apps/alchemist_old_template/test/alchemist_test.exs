defmodule AlchemistTest do
  use ExUnit.Case
  doctest Alchemist

  test "greets the world" do
    assert Alchemist.hello() == :world
  end
end
