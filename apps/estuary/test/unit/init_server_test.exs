defmodule Estuary.InitServerTest do
  use ExUnit.Case
  use Placebo

  import Assertions
  import Mox

  alias Estuary.InitServer

  setup :set_mox_global
  setup :verify_on_exit!

  test "should initialize topic reader and table writer on the application startup" do
    expect(MockTable, :init, fn _ -> :ok end)
    expect(MockReader, :init, fn _ -> :ok end)

    assert {:ok, _} = InitServer.start_link(name: :foo)
  end

  @tag :capture_log
  test "should die (so the supervisor can restart it) when pipeline goes down" do
    expect(MockTable, :init, 1, fn _ -> :ok end)
    expect(MockReader, :init, 1, fn _ -> :ok end)

    assert {:ok, init_server_pid} = InitServer.start_link(name: :foo)
    Process.unlink(init_server_pid)

    DynamicSupervisor.stop(Pipeline.DynamicSupervisor, :test)

    assert_async do
      assert not Process.alive?(init_server_pid)
      assert is_nil(Process.whereis(Estuary.InitServer))
    end
  end
end
