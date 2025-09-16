defmodule Forklift.MinimalTest do
  use ExUnit.Case, async: true
  import Mox

  # set up a mock for the DateTime module
  Mox.defmock(DateTimeMock, for: Forklift.Test.DateTimeBehaviour)

  test "minimal test" do
    stub(DateTimeMock, :utc_now, fn -> ~U[2023-01-01 00:00:00Z] end)
    assert DateTimeMock.utc_now() == ~U[2023-01-01 00:00:00Z]
  end
end
