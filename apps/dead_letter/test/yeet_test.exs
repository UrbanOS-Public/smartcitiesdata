defmodule YEETTest do
  use ExUnit.Case
  doctest YEET

  test "greets the world" do
    assert YEET.hello() == :world
  end
end
