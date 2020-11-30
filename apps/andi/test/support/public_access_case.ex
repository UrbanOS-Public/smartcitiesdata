defmodule AndiWeb.Test.PublicAccessCase do
  @moduledoc """
  This module flips AndiWeb into "Public Access" mode for a test module and resets it when done
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import AndiWeb.Test.PublicAccessCase
    end
  end

  setup_all do
    on_exit(set_access_level(:public))
    restart_andi()

    :ok
  end

  def set_access_level(level) do
    current = Application.get_env(:andi, :access_level)
    Application.put_env(:andi, :access_level, level)

    fn ->
      Application.put_env(:andi, :access_level, current)
      restart_andi()
    end
  end

  def restart_andi() do
    Application.stop(:andi)
    Application.stop(:brook)
    Application.stop(:elsa)

    Application.ensure_all_started(:andi)
  end
end
