defmodule ForkliftTest do
  use ExUnit.Case
  doctest Forklift

  test "greets the world" do
    assert Forklift.hello() == :world
  end
end
