defmodule FlairTest do
  use ExUnit.Case
  doctest Flair

  test "greets the world" do
    assert Flair.hello() == :world
  end
end
