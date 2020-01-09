defmodule Estuary.InitServerTest do
  use ExUnit.Case
  use Placebo

  import Assertions
  import Mox

  alias Estuary.InitServer

  setup :set_mox_global
  setup :verify_on_exit!

  test "should initialize topic reader and table writer on the application startup" do
    Application.ensure_all_started(:pipeline)

    expect(MockTable, :init, fn _ -> :ok end)
    expect(MockReader, :init, fn _ -> :ok end)

    assert {:ok, _} = InitServer.start_link(name: :foo)
  end

  @tag :capture_log
  test "should re-initialize topic reader if pipeline goes down" do
    expect(MockTable, :init, 1, fn _ -> :ok end)
    expect(MockReader, :init, 1, fn _ -> :ok end)
    stub(MockReader, :init, fn _ -> :ok end)

    assert {:ok, init_server_pid} = InitServer.start_link(name: :foo)

    DynamicSupervisor.stop(Pipeline.DynamicSupervisor, :test)

    assert_async do
      assert Process.whereis(Estuary.InitServer) |> Process.alive?()
    end
  end
end
