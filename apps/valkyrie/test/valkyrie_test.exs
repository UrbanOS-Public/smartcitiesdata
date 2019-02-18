defmodule ValkyrieTest do
  use ExUnit.Case
  doctest Valkyrie

  test "greets the world" do
    assert Valkyrie.hello() == :world
  end
end
