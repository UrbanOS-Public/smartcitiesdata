defmodule AndiWeb.Test.PublicAccessCase do
  @moduledoc """
  This module flips AndiWeb into "Public Access" mode for a test module and resets it when done
  """

  use ExUnit.CaseTemplate

  setup_all do
    on_exit(fn ->
      Application.put_env(:andi, :access_level, :private)
      restart_andi()
    end)

    Application.put_env(:andi, :access_level, :public)
    restart_andi()

    :ok
  end

  defp restart_andi() do
    Application.stop(:andi)
    Application.stop(:brook)
    Application.stop(:elsa)

    Application.ensure_all_started(:andi)
  end
end
