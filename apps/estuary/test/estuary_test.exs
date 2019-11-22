defmodule EstuaryTest do
  use ExUnit.Case
  doctest Estuary

  test "greets the world" do
    assert Estuary.hello() == :world
  end
end
