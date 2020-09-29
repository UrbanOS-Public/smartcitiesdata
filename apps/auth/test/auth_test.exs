defmodule AuthTest do
  use ExUnit.Case
  doctest Auth

  test "greets the world" do
    assert Auth.hello() == :world
  end
end
