defmodule PerformanceTest do
  use ExUnit.Case
  doctest Performance

  test "greets the world" do
    assert Performance.hello() == :world
  end
end
