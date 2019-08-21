defmodule Reaper.InitTest do
  use ExUnit.Case
  use Placebo

  import SmartCity.TestHelper

  alias Reaper.ConfigServer

  test "loads all reaper configs and passes them to config server" do
    allow Brook.get_all_values!(:reaper_config), return: [:reaper_config1, :reaper_config2, :reaper_config3]
    allow ConfigServer.process_reaper_config(any()), return: :ok

    {:ok, pid} = Reaper.Init.start_link([])

    eventually(fn ->
      assert_called Brook.get_all_values!(:reaper_config)
      assert_called ConfigServer.process_reaper_config(:reaper_config1)
      assert_called ConfigServer.process_reaper_config(:reaper_config2)
      assert_called ConfigServer.process_reaper_config(:reaper_config3)
      assert num_calls(ConfigServer.process_reaper_config(any())) == 3
      assert false == Process.alive?(pid)
    end)
  end
end
