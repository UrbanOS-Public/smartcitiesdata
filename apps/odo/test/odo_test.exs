defmodule OdoTest do
  use ExUnit.Case
  doctest Odo

  test "greets the world" do
    assert Odo.hello() == :world
  end
end
