defmodule Forklift.Integration.InitTest do
  use ExUnit.Case
  use Placebo

  import Mox
  alias SmartCity.TestDataGenerator, as: TDG

  setup :set_mox_global
  setup :verify_on_exit!

  test "starts a dataset topic reader for each dataset view state" do
    test = self()
    expect(Forklift.MockReader, :init, 2, fn args -> send(test, args[:dataset]) end)

    dataset1 = TDG.create_dataset(%{id: "view-state-1"})
    dataset2 = TDG.create_dataset(%{id: "view-state-2"})

    allow Brook.get_all_values!(:forklift, :datasets_to_process), return: [dataset1, dataset2]
    Forklift.Init.start_link([])

    assert_receive %SmartCity.Dataset{id: "view-state-1"}
    assert_receive %SmartCity.Dataset{id: "view-state-2"}
  end

  test "terminates after initialization" do
    expect(Forklift.MockReader, :init, 0, fn _ -> :ok end)
    allow Brook.get_all_values!(:forklift, :datasets_to_process), return: []

    {:ok, pid} = Forklift.Init.start_link([])
    Process.monitor(pid)

    assert_receive {:DOWN, _, _, ^pid, :normal}
  end
end
