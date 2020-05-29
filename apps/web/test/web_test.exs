defmodule WebTest do
  use ExUnit.Case
  doctest Web

  test "greets the world" do
    assert Web.hello() == :world
  end
end
