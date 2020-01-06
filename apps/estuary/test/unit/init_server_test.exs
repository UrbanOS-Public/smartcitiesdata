defmodule Estuary.InitServerTest do
  use ExUnit.Case

  import Mox

  alias Estuary.InitServer

  setup :set_mox_global
  setup :verify_on_exit!

  test "should initialize topic reader and table writer on the application startup" do
    expect(MockTable, :init, fn _ -> :ok end)
    expect(MockReader, :init, fn _ -> :ok end)

    assert {:ok, _} = InitServer.start_link(name: :foo)
  end
end
